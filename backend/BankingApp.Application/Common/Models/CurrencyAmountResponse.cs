namespace BankingApp.Application.Common.Models;

public class CurrencyAmountResponse
{
    public string Currency { get; set; } = string.Empty;

    public decimal Amount { get; set; }
}
