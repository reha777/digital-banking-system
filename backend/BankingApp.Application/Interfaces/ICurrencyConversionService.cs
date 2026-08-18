namespace BankingApp.Application.Interfaces
{
    public interface ICurrencyConversionService
    {
        bool IsSupported(string currency);
        decimal Convert(decimal amount, string fromCurrency, string toCurrency);
        decimal GetRate(string fromCurrency, string toCurrency);
        decimal ToBam(decimal amount, string currency);
    }
}
