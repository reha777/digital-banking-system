using BankingApp.Domain.Enums;
namespace BankingApp.Domain.Entities;
public sealed class ReportJob
{
    public Guid Id { get; set; }
    public ReportType Type { get; set; }
    public Guid RequestedByUserId { get; set; }
    public ReportJobStatus Status { get; set; }
    public DateTime RequestedAtUtc { get; set; }
    public DateTime? StartedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public DateTime? FailedAtUtc { get; set; }
    public string? FileName { get; set; }
    public string? StoragePath { get; set; }
    public string? ErrorMessage { get; set; }
    public string FilterJson { get; set; } = "{}";
    public string? CorrelationId { get; set; }
    public User RequestedByUser { get; set; } = null!;
}
