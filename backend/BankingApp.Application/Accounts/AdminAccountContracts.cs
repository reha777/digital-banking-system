using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Accounts;

public sealed class AdminAccountQueryRequest : PagedRequest
{
    public string? Search { get; set; }
    public AccountStatus? Status { get; set; }
}

public sealed class AdminAccountResponse
{
    public Guid Id { get; set; }
    public Guid CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string AccountNumber { get; set; } = string.Empty;
    public Guid AccountTypeId { get; set; }
    public string AccountTypeCode { get; set; } = string.Empty;
    public string AccountTypeName { get; set; } = string.Empty;
    public string AccountType => AccountTypeName;
    public AccountStatus Status { get; set; }
    public decimal Balance { get; set; }
    public string Currency { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CardId { get; set; }
    public CardStatus? CardStatus { get; set; }
}
