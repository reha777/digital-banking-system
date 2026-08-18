using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;

namespace BankingApp.Infrastructure.Services
{
    public class DemoCurrencyConversionService : ICurrencyConversionService
    {
        // Fixed educational/demo rates expressed as BAM value of one currency unit.
        private static readonly IReadOnlyDictionary<string, decimal> BamRates =
            new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
            {
                ["BAM"] = 1m,
                ["EUR"] = 1.95583m,
                ["USD"] = 1.80m
            };

        public bool IsSupported(string currency) =>
            !string.IsNullOrWhiteSpace(currency) && BamRates.ContainsKey(currency.Trim());

        public decimal Convert(decimal amount, string fromCurrency, string toCurrency) =>
            decimal.Round(amount * GetRate(fromCurrency, toCurrency), 2, MidpointRounding.AwayFromZero);

        public decimal GetRate(string fromCurrency, string toCurrency)
        {
            var from = Rate(fromCurrency);
            var to = Rate(toCurrency);
            return decimal.Round(from / to, 8, MidpointRounding.AwayFromZero);
        }

        public decimal ToBam(decimal amount, string currency) =>
            decimal.Round(amount * Rate(currency), 2, MidpointRounding.AwayFromZero);

        private static decimal Rate(string currency)
        {
            if (string.IsNullOrWhiteSpace(currency) ||
                !BamRates.TryGetValue(currency.Trim(), out var rate))
            {
                throw new BusinessException("Valuta nije podrzana. Dozvoljene valute su USD, EUR i BAM.");
            }
            return rate;
        }
    }
}
