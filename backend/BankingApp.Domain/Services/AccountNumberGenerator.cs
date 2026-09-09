namespace BankingApp.Domain.Services;

public static class AccountNumberGenerator
{
    public static string Create(Guid accountId, string accountTypeCode)
    {
        if (accountId == Guid.Empty)
            throw new ArgumentException("Account ID must not be empty.", nameof(accountId));

        if (string.IsNullOrWhiteSpace(accountTypeCode))
            throw new ArgumentException("Account type code must not be empty.", nameof(accountTypeCode));

        return $"BA-{accountId:N}"[..23].ToUpperInvariant() + $"-{accountTypeCode.Trim().ToUpperInvariant()}";
    }
}
