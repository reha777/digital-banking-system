using System.Text;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace BankingApp.Worker;

public sealed class Worker(
    IOptions<RabbitMqConsumerOptions> configuredOptions,
    AuditArchiveMessageHandler handler,
    ILogger<Worker> logger) : BackgroundService
{
    private IConnection? connection;
    private IModel? channel;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var options = configuredOptions.Value;
        var factory = new ConnectionFactory
        {
            HostName = options.Host,
            Port = options.Port,
            UserName = options.UserName,
            Password = options.Password,
            DispatchConsumersAsync = true,
            AutomaticRecoveryEnabled = true
        };
        await ConnectAsync(factory, stoppingToken);
        var activeChannel = channel
            ?? throw new InvalidOperationException("RabbitMQ channel was not created.");
        activeChannel.QueueDeclare(options.AuditArchiveQueue, durable: true,
            exclusive: false, autoDelete: false, arguments: null);
        activeChannel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false);

        var consumer = new AsyncEventingBasicConsumer(activeChannel);
        consumer.Received += async (_, delivery) =>
        {
            try
            {
                var result = await handler.HandleAsync(delivery.Body, stoppingToken);
                activeChannel.BasicAck(delivery.DeliveryTag, multiple: false);
                logger.LogInformation(
                    "Audit archive job {JobId} completed at {Path} with {EntryCount} entries.",
                    result.JobId, result.Path, result.EntryCount);
            }
            catch (InvalidAuditArchiveMessageException exception)
            {
                logger.LogWarning(exception, "Rejecting invalid audit archive message {Body}.",
                    Encoding.UTF8.GetString(delivery.Body.Span));
                activeChannel.BasicNack(delivery.DeliveryTag, multiple: false, requeue: false);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                activeChannel.BasicNack(delivery.DeliveryTag, multiple: false, requeue: true);
            }
            catch (Exception exception)
            {
                logger.LogError(exception,
                    "Audit archive processing failed; message will be retried.");
                activeChannel.BasicNack(delivery.DeliveryTag, multiple: false, requeue: true);
            }
        };
        activeChannel.BasicConsume(options.AuditArchiveQueue, autoAck: false, consumer);

        logger.LogInformation("Consuming durable queue {Queue}.", options.AuditArchiveQueue);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ConnectAsync(ConnectionFactory factory, CancellationToken stoppingToken)
    {
        var attempt = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            attempt++;
            try
            {
                connection = factory.CreateConnection();
                channel = connection.CreateModel();
                logger.LogInformation(
                    "Connected to RabbitMQ at {Host}:{Port} after {AttemptCount} attempt(s).",
                    factory.HostName,
                    factory.Port,
                    attempt);
                return;
            }
            catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
            {
                channel?.Dispose();
                connection?.Dispose();
                channel = null;
                connection = null;
                var delay = TimeSpan.FromSeconds(Math.Min(attempt * 2, 10));
                logger.LogWarning(
                    exception,
                    "RabbitMQ connection attempt {AttemptCount} failed. Retrying in {DelaySeconds} seconds.",
                    attempt,
                    delay.TotalSeconds);
                await Task.Delay(delay, stoppingToken);
            }
        }

        stoppingToken.ThrowIfCancellationRequested();
    }

    public override void Dispose()
    {
        channel?.Dispose();
        connection?.Dispose();
        base.Dispose();
    }
}
