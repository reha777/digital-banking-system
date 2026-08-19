using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions;

public class TransactionStatisticsQuery
{
    public Guid? AccountId { get; set; }

    public DateTime From { get; set; }

    public DateTime To { get; set; }
}

public class TransactionStatisticsResponse
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public Guid? AccountId { get; set; }

    public IReadOnlyCollection<StatisticsAccountResponse> Accounts { get; set; } = [];

    public IReadOnlyCollection<CurrencyStatisticsResponse> CurrencySeries { get; set; } = [];
}

public class StatisticsAccountResponse
{
    public Guid Id { get; set; }

    public string AccountNumber { get; set; } = string.Empty;

    public AccountType AccountType { get; set; }

    public decimal Balance { get; set; }

    public string Currency { get; set; } = string.Empty;
}

public class CurrencyStatisticsResponse
{
    public string Currency { get; set; } = string.Empty;

    public decimal Balance { get; set; }

    public IReadOnlyCollection<MonthlyStatisticsResponse> Months { get; set; } = [];
}

public class MonthlyStatisticsResponse
{
    public int Year { get; set; }

    public int Month { get; set; }

    public decimal Income { get; set; }

    public decimal Spending { get; set; }

    public decimal Net => Income - Spending;

    public IReadOnlyCollection<TransactionResponse> RecentTransactions { get; set; } = [];
}
