using BankingApp.Application.Common.Models;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Customers;

public class AdminCustomerDetailsResponse
{
    public Guid Id { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public CustomerStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public IReadOnlyCollection<CurrencyAmountResponse> Balances { get; set; } = [];
    public IReadOnlyCollection<AdminCustomerAccountResponse> Accounts { get; set; } = [];
    public AdminCustomerRelationshipSummaryResponse Summary { get; set; } = new();
}

public class AdminCustomerAccountResponse
{
    public Guid Id { get; set; }
    public string AccountNumber { get; set; } = string.Empty;
    public AccountType AccountType { get; set; }
    public decimal Balance { get; set; }
    public string Currency { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public AdminCustomerCardResponse? Card { get; set; }
}

public class AdminCustomerCardResponse
{
    public Guid Id { get; set; }
    public string MaskedCardNumber { get; set; } = string.Empty;
    public string CardholderName { get; set; } = string.Empty;
    public DateTime ExpiryDate { get; set; }
    public CardBrand Brand { get; set; }
    public CardStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public class AdminCustomerRelationshipSummaryResponse
{
    public int AccountCount { get; set; }
    public int CardCount { get; set; }
    public int ActiveLoanCount { get; set; }
    public int PendingCardRequestCount { get; set; }
    public int PendingTransactionReviewCount { get; set; }
    public int PendingLoanApplicationCount { get; set; }
}
