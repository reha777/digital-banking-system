using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class FinalDemoSeedTests
{
    [Fact]
    public void Clean_seed_contains_final_three_demo_accounts_and_two_way_history()
    {
        using var db = new BankingAppDbContext(
            new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var hasher = new Pbkdf2PasswordHasher();

        var users = Seed<User>(db).ToDictionary(value => (string)value[nameof(User.Email)]!);
        Assert.Equal(3, users.Count);
        foreach (var email in new[]
                 {
                     "mobile@bankingapp.local",
                     "recipient@bankingapp.local",
                     "admin@bankingapp.local",
                 })
        {
            var hash = (string)users[email][nameof(User.PasswordHash)]!;
            Assert.True(hasher.Verify("test123", hash));
            Assert.False(hasher.Verify("test", hash));
        }

        var accounts = Seed<Account>(db).ToList();
        Assert.Equal(4, accounts.Count);
        Assert.Equal(4, accounts.Select(value => value[nameof(Account.AccountNumber)]).Distinct().Count());
        Assert.Equal(2, accounts.Count(value => (decimal)value[nameof(Account.Balance)]! == 20000m));
        Assert.Equal(2, accounts.Count(value => (decimal)value[nameof(Account.Balance)]! == 5000m));

        var cards = Seed<BankCard>(db).ToList();
        Assert.Equal(4, cards.Count);
        Assert.Equal(4, cards.Select(value => value[nameof(BankCard.CardNumber)]).Distinct().Count());

        var transactions = Seed<Transaction>(db).ToList();
        Assert.Contains(transactions, value =>
            (decimal)value[nameof(Transaction.Amount)]! < 0 &&
            (Guid?)value[nameof(Transaction.DestinationAccountId)] ==
            Guid.Parse("deed75d2-e898-4c2d-a7e3-2fa1152d7222"));
        Assert.Contains(transactions, value =>
            (decimal)value[nameof(Transaction.Amount)]! < 0 &&
            (Guid?)value[nameof(Transaction.DestinationAccountId)] ==
            Guid.Parse("dbdd0766-a83e-4a7d-944c-af7d0373ff50"));
    }

    private static IEnumerable<IDictionary<string, object?>> Seed<TEntity>(
        BankingAppDbContext db) where TEntity : class =>
        db.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(TEntity))!
            .GetSeedData();
}
