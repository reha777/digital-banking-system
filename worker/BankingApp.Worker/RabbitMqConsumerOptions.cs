using BankingApp.Application.Messaging;

namespace BankingApp.Worker;

public sealed class RabbitMqConsumerOptions
{
    public const string SectionName = "RabbitMq";
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 5672;
    public string UserName { get; set; } = "guest";
    public string Password { get; set; } = "guest";
    public string AuditArchiveQueue { get; set; } = MessagingQueues.AuditArchive;
    public string ReportGenerationQueue { get; set; } = ReportQueues.Generation;
}
