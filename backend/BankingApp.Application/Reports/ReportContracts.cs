using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;
namespace BankingApp.Application.Reports;
public sealed class TransactionReportRequest { public DateTime? DateFrom { get; init; } public DateTime? DateTo { get; init; } public TransactionStatus? Status { get; init; } public TransactionType? TransactionType { get; init; } public string? Currency { get; init; } }
public sealed class LoanPortfolioReportRequest { public DateTime? DateFrom { get; init; } public DateTime? DateTo { get; init; } public LoanStatus? Status { get; init; } public bool OverdueOnly { get; init; } public string? Currency { get; init; } }
public sealed class ReportJobQuery : PagedRequest { }
public sealed class ReportJobResponse { public Guid Id { get; init; } public string Type { get; init; } = string.Empty; public string Status { get; init; } = string.Empty; public string RequestedBy { get; init; } = string.Empty; public DateTime RequestedAtUtc { get; init; } public DateTime? CompletedAtUtc { get; init; } public string? FileName { get; init; } public bool DownloadAvailable { get; init; } public string? ErrorMessage { get; init; } }
public sealed record ReportFileResponse(byte[] Content, string FileName);
