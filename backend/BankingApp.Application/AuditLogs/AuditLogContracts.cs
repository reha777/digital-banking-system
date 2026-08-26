using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.AuditLogs;

public static class AuditLogActions
{
    public const string CustomerUpdated = nameof(CustomerUpdated);
    public const string CustomerStatusChanged = nameof(CustomerStatusChanged);
    public const string CustomerDeleted = nameof(CustomerDeleted);
    public const string TransactionApproved = nameof(TransactionApproved);
    public const string TransactionRejected = nameof(TransactionRejected);
    public const string TransactionDocumentsRequested = nameof(TransactionDocumentsRequested);
    public const string CardRequestApproved = nameof(CardRequestApproved);
    public const string CardRequestRejected = nameof(CardRequestRejected);
    public const string CardDocumentsRequested = nameof(CardDocumentsRequested);
    public const string LoanApproved = nameof(LoanApproved);
    public const string LoanRejected = nameof(LoanRejected);
    public const string AdminSettingsUpdated = nameof(AdminSettingsUpdated);
    public const string AdminProfileUpdated = nameof(AdminProfileUpdated);
    public const string ReportRequested = nameof(ReportRequested);
}

public static class AuditEntityTypes
{
    public const string Customer = nameof(Customer);
    public const string Transaction = nameof(Transaction);
    public const string CardRequest = nameof(CardRequest);
    public const string LoanApplication = nameof(LoanApplication);
    public const string AdminSettings = nameof(AdminSettings);
    public const string AdminProfile = nameof(AdminProfile);
    public const string ReportJob = nameof(ReportJob);
}

public sealed class AuditLogRecordRequest
{
    public required string Action { get; init; }
    public required string EntityType { get; init; }
    public required string EntityId { get; init; }
    public required string Description { get; init; }
    public string? Reason { get; init; }
    public string? OldValue { get; init; }
    public string? NewValue { get; init; }
    public string? CorrelationId { get; init; }
}

public sealed class AuditLogQueryRequest : PagedRequest
{
    public string? Search { get; set; }
    public string? Action { get; set; }
    public string? EntityType { get; set; }
    public DateTime? DateFrom { get; set; }
    public DateTime? DateTo { get; set; }
}

public sealed class AuditLogResponse
{
    public Guid Id { get; init; }
    public string ActorName { get; init; } = string.Empty;
    public string ActorRole { get; init; } = string.Empty;
    public string Action { get; init; } = string.Empty;
    public string ActionDisplayName { get; init; } = string.Empty;
    public string EntityType { get; init; } = string.Empty;
    public string EntityId { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string? Reason { get; init; }
    public string? OldValue { get; init; }
    public string? NewValue { get; init; }
    public string? CorrelationId { get; init; }
    public DateTime CreatedAtUtc { get; init; }
}
