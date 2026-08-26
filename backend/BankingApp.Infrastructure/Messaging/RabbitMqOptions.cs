using BankingApp.Application.Messaging;
using Microsoft.Extensions.Options;

namespace BankingApp.Infrastructure.Messaging;

public sealed class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";

    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 5672;
    public string UserName { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string AuditArchiveQueue { get; set; } = MessagingQueues.AuditArchive;
    public string ReportGenerationQueue { get; set; } = ReportQueues.Generation;
}

public sealed class RabbitMqOptionsValidator : IValidateOptions<RabbitMqOptions>
{
    public ValidateOptionsResult Validate(string? name, RabbitMqOptions options)
    {
        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(options.Host)) missing.Add("RabbitMq:Host");
        if (options.Port is < 1 or > 65535) missing.Add("RabbitMq:Port");
        if (string.IsNullOrWhiteSpace(options.UserName)) missing.Add("RabbitMq:UserName");
        if (string.IsNullOrWhiteSpace(options.Password)) missing.Add("RabbitMq:Password");
        if (string.IsNullOrWhiteSpace(options.AuditArchiveQueue)) missing.Add("RabbitMq:AuditArchiveQueue");
        if (string.IsNullOrWhiteSpace(options.ReportGenerationQueue)) missing.Add("RabbitMq:ReportGenerationQueue");
        return missing.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(
                $"RabbitMQ configuration is incomplete. Missing or invalid: {string.Join(", ", missing)}.");
    }
}
