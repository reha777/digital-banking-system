using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Cards;

public class AdminIssuedCardQueryRequest : PagedRequest
{
    public string? Search { get; set; }
    public CardStatus? Status { get; set; }
}

public class AdminIssuedCardResponse
{
    public Guid Id { get; set; }
    public Guid CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string MaskedCardNumber { get; set; } = string.Empty;
    public string CardholderName { get; set; } = string.Empty;
    public CardBrand Brand { get; set; }
    public DateTime ExpiryDate { get; set; }
    public CardStatus Status { get; set; }
    public Guid AccountId { get; set; }
    public string AccountNumber { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}
