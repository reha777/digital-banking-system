using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Services;

public static class AccountNumberGenerator
{
    public static string Create(Guid accountId, AccountType accountType)
    {
        if (accountId == Guid.Empty)
            throw new ArgumentException("Account ID must not be empty.", nameof(accountId));

        return $"BA-{accountId:N}"[..23].ToUpperInvariant() + $"-{accountType.ToString().ToUpperInvariant()}";
    }
}
