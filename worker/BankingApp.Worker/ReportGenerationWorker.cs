using Microsoft.Extensions.Options;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace BankingApp.Worker;

public sealed class ReportGenerationWorker(IOptions<RabbitMqConsumerOptions> configured, IServiceScopeFactory scopes, ILogger<ReportGenerationWorker> logger) : BackgroundService
{
    private IConnection? connection; private IModel? channel;
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var options = configured.Value; var factory = new ConnectionFactory { HostName = options.Host, Port = options.Port, UserName = options.UserName, Password = options.Password, DispatchConsumersAsync = true, AutomaticRecoveryEnabled = true };
        while (!stoppingToken.IsCancellationRequested) { try { connection = factory.CreateConnection(); channel = connection.CreateModel(); break; } catch (Exception ex) { logger.LogWarning(ex, "Report consumer is waiting for RabbitMQ."); await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); } }
        var active = channel ?? throw new InvalidOperationException("RabbitMQ channel was not created."); active.QueueDeclare(options.ReportGenerationQueue, true, false, false, null); active.BasicQos(0, 1, false);
        var consumer = new AsyncEventingBasicConsumer(active); consumer.Received += async (_, delivery) =>
        {
            try { using var scope = scopes.CreateScope(); await scope.ServiceProvider.GetRequiredService<ReportGenerationHandler>().HandleAsync(delivery.Body, stoppingToken); active.BasicAck(delivery.DeliveryTag, false); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { active.BasicNack(delivery.DeliveryTag, false, true); }
            catch (Exception ex) when (ex is SqlException or DbUpdateException) { logger.LogError(ex, "Report infrastructure failed; message will be retried."); active.BasicNack(delivery.DeliveryTag, false, true); }
            catch (InvalidDataException ex) { logger.LogWarning(ex, "Rejecting invalid report message."); active.BasicNack(delivery.DeliveryTag, false, false); }
            catch (Exception ex) { logger.LogError(ex, "Report job failed and was persisted as failed."); active.BasicAck(delivery.DeliveryTag, false); }
        };
        active.BasicConsume(options.ReportGenerationQueue, false, consumer); logger.LogInformation("Consuming durable queue {Queue}.", options.ReportGenerationQueue); await Task.Delay(Timeout.Infinite, stoppingToken);
    }
    public override void Dispose() { channel?.Dispose(); connection?.Dispose(); base.Dispose(); }
}
