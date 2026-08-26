using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.ReferenceData;

public static class ReferenceDataTypes
{
    public const string LoanPurposes = "loan-purposes";
    public const string DocumentTypes = "document-types";
    public const string TransactionCategories = "transaction-categories";
    public static readonly IReadOnlySet<string> All = new HashSet<string>(
        [LoanPurposes, DocumentTypes, TransactionCategories], StringComparer.OrdinalIgnoreCase);
}

public sealed class ReferenceDataResponse
{
    public Guid Id { get; init; }
    public string Type { get; init; } = string.Empty;
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string? Description { get; init; }
    public bool IsActive { get; init; }
    public int SortOrder { get; init; }
}

public sealed class ReferenceDataQuery : PagedRequest
{
    public string? Search { get; init; }
    public bool? IsActive { get; init; }
}

public sealed class ReferenceDataWriteRequest
{
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string? Description { get; init; }
    public bool IsActive { get; init; } = true;
    public int SortOrder { get; init; }
}
