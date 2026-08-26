using System.Text.Json;

namespace BankingApp.Application.Messaging;

public static class MessagingQueues
{
    public const string AuditArchive = "banking.audit-archive.v1";
}

public sealed record AuditArchiveEntry(
    Guid Id,
    Guid ActorUserId,
    string ActorName,
    string ActorRole,
    string Action,
    string EntityType,
    string EntityId,
    string Description,
    string? Reason,
    string? OldValue,
    string? NewValue,
    string? CorrelationId,
    DateTime CreatedAtUtc);

public sealed record AuditArchiveRequested(
    Guid JobId,
    Guid RequestedByUserId,
    DateTime RequestedAtUtc,
    DateTime? DateFromUtc,
    DateTime? DateToUtc,
    IReadOnlyList<AuditArchiveEntry> Entries);

public static class AuditArchiveMessageSerializer
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public static byte[] Serialize(AuditArchiveRequested message) =>
        JsonSerializer.SerializeToUtf8Bytes(message, Options);

    public static AuditArchiveRequested? Deserialize(ReadOnlySpan<byte> body) =>
        JsonSerializer.Deserialize<AuditArchiveRequested>(body, Options);
}

public sealed class AuditArchiveCreateRequest
{
    public DateTime? DateFromUtc { get; init; }
    public DateTime? DateToUtc { get; init; }
}

public sealed record AuditArchiveJobResponse(Guid JobId, int EntryCount, string Status);
