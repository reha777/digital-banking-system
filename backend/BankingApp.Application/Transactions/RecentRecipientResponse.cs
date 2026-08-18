namespace BankingApp.Application.Transactions;

public record RecentRecipientResponse(
    Guid AccountId,
    string FirstName,
    string LastName,
    string AccountNumber,
    DateTime? LastUsedAtUtc);
