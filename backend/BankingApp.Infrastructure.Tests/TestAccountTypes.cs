using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Seeds the account type reference rows that every Account row points at.
/// The relational schema seeds them through a migration and enforces the FK,
/// so in-memory fixtures have to add them explicitly.
/// </summary>
internal static class TestAccountTypes
{
    public static BankingAppDbContext SeedAccountTypes(this BankingAppDbContext db)
    {
        if (!db.AccountTypeDefinitions.Any())
        {
            db.AccountTypeDefinitions.AddRange(
                Definition(AccountTypeCodes.CheckingId, AccountTypeCodes.Checking, "Checking"),
                Definition(AccountTypeCodes.SavingsId, AccountTypeCodes.Savings, "Savings"));
        }

        return db;
    }

    private static AccountTypeDefinition Definition(Guid id, string code, string name) => new()
    {
        Id = id,
        Code = code,
        Name = name,
        IsActive = true,
        CreatedAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
    };
}
