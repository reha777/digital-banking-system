using System.Security.Cryptography;
using BankingApp.Infrastructure.Messaging;
using Microsoft.Extensions.Options;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace BankingApp.Worker;

public sealed class ReportGenerationWorker(IOptions<RabbitMqConsumerOptions> configured, IServiceScopeFactory scopes, ILogger<ReportGenerationWorker> logger) : BackgroundService
{
    private readonly MessageRetryPolicy retryPolicy = new();
    private IConnection? connection; private IModel? channel;
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var options = configured.Value; var factory = new ConnectionFactory { HostName = options.Host, Port = options.Port, UserName = options.UserName, Password = options.Password, DispatchConsumersAsync = true, AutomaticRecoveryEnabled = true };
        var connectionAttempt = 0;
        while (!stoppingToken.IsCancellationRequested) { try { connection = factory.CreateConnection(); channel = connection.CreateModel(); break; } catch (Exception ex) { connectionAttempt++; var delay = ExponentialBackoff.GetDelay(connectionAttempt); logger.LogWarning(ex, "Report consumer connection attempt {AttemptCount} failed; retrying in {DelaySeconds} seconds.", connectionAttempt, delay.TotalSeconds); await Task.Delay(delay, stoppingToken); } }
        var active = channel ?? throw new InvalidOperationException("RabbitMQ channel was not created."); active.QueueDeclare(options.ReportGenerationQueue, true, false, false, null); active.BasicQos(0, 1, false);
        var consumer = new AsyncEventingBasicConsumer(active); consumer.Received += async (_, delivery) =>
        {
            var messageKey = delivery.BasicProperties.MessageId ?? Convert.ToHexString(SHA256.HashData(delivery.Body.Span));
            try { using var scope = scopes.CreateScope(); await scope.ServiceProvider.GetRequiredService<ReportGenerationHandler>().HandleAsync(delivery.Body, stoppingToken); retryPolicy.Clear(messageKey); active.BasicAck(delivery.DeliveryTag, false); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { active.BasicNack(delivery.DeliveryTag, false, true); }
            catch (Exception ex) when (ex is SqlException or DbUpdateException) { var retry = retryPolicy.RegisterFailure(messageKey); if (!retry.ShouldRetry) { retryPolicy.Clear(messageKey); logger.LogError(ex, "Report infrastructure failed after {AttemptCount} attempts; rejecting message.", retry.Attempt); active.BasicNack(delivery.DeliveryTag, false, false); } else { logger.LogError(ex, "Report infrastructure attempt {AttemptCount} failed; retrying after {DelaySeconds} seconds.", retry.Attempt, retry.Delay.TotalSeconds); await Task.Delay(retry.Delay, stoppingToken); active.BasicNack(delivery.DeliveryTag, false, true); } }
            catch (InvalidDataException ex) { retryPolicy.Clear(messageKey); logger.LogWarning(ex, "Rejecting invalid report message."); active.BasicNack(delivery.DeliveryTag, false, false); }
            catch (Exception ex) { retryPolicy.Clear(messageKey); logger.LogError(ex, "Report job failed and was persisted as failed."); active.BasicAck(delivery.DeliveryTag, false); }
        };
        active.BasicConsume(options.ReportGenerationQueue, false, consumer); logger.LogInformation("Consuming durable queue {Queue}.", options.ReportGenerationQueue); await Task.Delay(Timeout.Infinite, stoppingToken);
    }
    public override void Dispose() { channel?.Dispose(); connection?.Dispose(); base.Dispose(); }
}
