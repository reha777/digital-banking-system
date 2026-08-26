using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
namespace BankingApp.Infrastructure.Messaging;
public sealed class RabbitMqReportGenerationPublisher(IOptions<RabbitMqOptions> configured) : IReportGenerationPublisher
{
    public Task PublishAsync(ReportGenerationRequested message, CancellationToken token = default)
    {
        token.ThrowIfCancellationRequested(); var o = configured.Value;
        var factory = new ConnectionFactory { HostName = o.Host, Port = o.Port, UserName = o.UserName, Password = o.Password, AutomaticRecoveryEnabled = true };
        using var connection = factory.CreateConnection(); using var channel = connection.CreateModel();
        channel.QueueDeclare(o.ReportGenerationQueue, true, false, false, null); var p = channel.CreateBasicProperties(); p.Persistent = true; p.ContentType = "application/json"; p.MessageId = message.JobId.ToString("N");
        channel.BasicPublish("", o.ReportGenerationQueue, p, ReportGenerationMessageSerializer.Serialize(message)); return Task.CompletedTask;
    }
}
