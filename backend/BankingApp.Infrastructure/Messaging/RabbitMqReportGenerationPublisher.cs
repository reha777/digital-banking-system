using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace BankingApp.Infrastructure.Messaging;

public sealed class RabbitMqReportGenerationPublisher :
    IReportGenerationPublisher,
    IDisposable
{
    private readonly object sync = new();
    private readonly RabbitMqOptions options;
    private IConnection? connection;
    private IModel? channel;

    public RabbitMqReportGenerationPublisher(IOptions<RabbitMqOptions> options)
    {
        this.options = options.Value;
    }

    public Task PublishAsync(
        ReportGenerationRequested message,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var body = ReportGenerationMessageSerializer.Serialize(message);
        lock (sync)
        {
            EnsureConnected();
            var properties = channel!.CreateBasicProperties();
            properties.Persistent = true;
            properties.ContentType = "application/json";
            properties.Type = nameof(ReportGenerationRequested);
            properties.MessageId = message.JobId.ToString("N");
            channel.BasicPublish(
                exchange: string.Empty,
                routingKey: options.ReportGenerationQueue,
                basicProperties: properties,
                body: body);
            channel.WaitForConfirmsOrDie(TimeSpan.FromSeconds(5));
        }
        return Task.CompletedTask;
    }

    private void EnsureConnected()
    {
        if (connection?.IsOpen == true && channel?.IsOpen == true) return;
        channel?.Dispose();
        connection?.Dispose();
        var factory = new ConnectionFactory
        {
            HostName = options.Host,
            Port = options.Port,
            UserName = options.UserName,
            Password = options.Password,
            AutomaticRecoveryEnabled = true
        };
        connection = factory.CreateConnection();
        channel = connection.CreateModel();
        channel.QueueDeclare(
            options.ReportGenerationQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null);
        channel.ConfirmSelect();
    }

    public void Dispose()
    {
        lock (sync)
        {
            channel?.Dispose();
            connection?.Dispose();
        }
    }
}
