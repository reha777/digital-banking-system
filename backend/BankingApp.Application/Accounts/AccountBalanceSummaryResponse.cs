namespace BankingApp.Application.Accounts
{
    public class AccountBalanceSummaryResponse
    {
        public IReadOnlyCollection<CurrencyBalanceResponse> Totals { get; set; } = [];

        public IReadOnlyCollection<AccountResponse> Accounts { get; set; } = [];
    }

    public class CurrencyBalanceResponse
    {
        public string Currency { get; set; } = string.Empty;

        public decimal Balance { get; set; }
    }
}
