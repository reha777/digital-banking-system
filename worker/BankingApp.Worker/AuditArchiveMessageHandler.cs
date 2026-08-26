using BankingApp.Application.Messaging;

namespace BankingApp.Worker;

public sealed class AuditArchiveMessageHandler(IAuditArchiveWriter writer)
{
    public async Task<AuditArchiveWriteResult> HandleAsync(
        ReadOnlyMemory<byte> body,
        CancellationToken cancellationToken = default)
    {
        AuditArchiveRequested? message;
        try
        {
            message = AuditArchiveMessageSerializer.Deserialize(body.Span);
        }
        catch (Exception exception) when (
            exception is System.Text.Json.JsonException or NotSupportedException)
        {
            throw new InvalidAuditArchiveMessageException(
                "Message is not valid JSON.", exception);
        }

        if (message is null || message.JobId == Guid.Empty ||
            message.RequestedByUserId == Guid.Empty ||
            message.RequestedAtUtc == default || message.Entries is null)
            throw new InvalidAuditArchiveMessageException(
                "Message is missing required audit archive data.");
        if (message.Entries.Any(entry => entry.Id == Guid.Empty ||
                string.IsNullOrWhiteSpace(entry.Action) ||
                string.IsNullOrWhiteSpace(entry.EntityType) ||
                string.IsNullOrWhiteSpace(entry.Description)))
            throw new InvalidAuditArchiveMessageException(
                "Message contains an invalid audit entry.");

        return await writer.WriteAsync(message, cancellationToken);
    }
}

public sealed class InvalidAuditArchiveMessageException : Exception
{
    public InvalidAuditArchiveMessageException(
        string message,
        Exception? innerException = null) : base(message, innerException)
    {
    }
}
