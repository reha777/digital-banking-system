namespace BankingApp.Domain.Constants;

public static class SupportedCurrencies
{
    public const string Bam = "BAM";
    public const string Eur = "EUR";
    public const string Usd = "USD";

    public static readonly IReadOnlySet<string> All =
        new HashSet<string>([Bam, Eur, Usd], StringComparer.OrdinalIgnoreCase);

    public static bool IsSupported(string? currency) =>
        !string.IsNullOrWhiteSpace(currency) && All.Contains(currency.Trim());

    public static string Normalize(string currency) =>
        currency.Trim().ToUpperInvariant();
}
