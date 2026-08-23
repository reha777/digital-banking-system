namespace BankingApp.Domain.Entities;

public class AuditLog
{
    public Guid Id { get; set; }
    public Guid ActorUserId { get; set; }
    public string ActorName { get; set; } = string.Empty;
    public string ActorRole { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public string EntityId { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? Reason { get; set; }
    public string? OldValue { get; set; }
    public string? NewValue { get; set; }
    public string? CorrelationId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
