using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class TransactionStatisticsTests
{
    [Fact]
    public async Task All_accounts_excludes_both_sides_of_internal_transfer()
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetStatisticsAsync(fixture.Query());
        var usd = Assert.Single(result.CurrencySeries, series => series.Currency == "USD");
        var month = usd.Months.Single(value => value.Month == DateTime.UtcNow.Month);

        Assert.Equal(50, month.Spending);
        Assert.Equal(0, month.Income);
        Assert.Single(month.RecentTransactions);
    }

    [Fact]
    public async Task Single_account_includes_internal_transfer_for_that_account()
    {
        await using var fixture = await Fixture.CreateAsync();
        var query = fixture.Query();
        query.AccountId = fixture.Checking.Id;
        var result = await fixture.Service.GetStatisticsAsync(query);
        var month = Assert.Single(result.CurrencySeries).Months
            .Single(value => value.Month == DateTime.UtcNow.Month);

        Assert.Equal(150, month.Spending);
        Assert.Equal(2, month.RecentTransactions.Count);
    }

    [Fact]
    public async Task Different_currencies_have_separate_balances_and_series()
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetStatisticsAsync(fixture.Query());

        Assert.Equal(2, result.CurrencySeries.Count);
        Assert.Equal(900, result.CurrencySeries.Single(value => value.Currency == "USD").Balance);
        Assert.Equal(300, result.CurrencySeries.Single(value => value.Currency == "EUR").Balance);
    }

    [Fact]
    public async Task Foreign_account_filter_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var query = fixture.Query();
        query.AccountId = fixture.ForeignAccount.Id;

        await Assert.ThrowsAsync<NotFoundException>(() =>
            fixture.Service.GetStatisticsAsync(query));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(
            BankingAppDbContext db,
            User owner,
            Account checking,
            Account foreignAccount)
        {
            Db = db;
            Checking = checking;
            ForeignAccount = foreignAccount;
            Service = new TransactionService(
                db,
                new CurrentUser(owner.Id),
                new DemoCurrencyConversionService());
        }

        public BankingAppDbContext Db { get; }
        public TransactionService Service { get; }
        public Account Checking { get; }
        public Account ForeignAccount { get; }

        public TransactionStatisticsQuery Query() => new()
        {
            From = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1).AddMonths(-5),
            To = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1).AddMonths(1)
        };

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var foreign = User("Foreign");
            var checking = Account(owner, "checking", "USD", 700);
            var savings = Account(owner, "savings", "USD", 200);
            var euro = Account(owner, "euro", "EUR", 300);
            var foreignAccount = Account(foreign, "foreign", "USD", 100);
            db.Users.AddRange(owner, foreign);
            db.Accounts.AddRange(checking, savings, euro, foreignAccount);
            var now = DateTime.UtcNow;
            db.Transactions.AddRange(
                Transaction(checking, -100, checking.Id, savings.Id, "INTERNAL", now),
                Transaction(savings, 100, checking.Id, savings.Id, "INTERNAL", now),
                Transaction(checking, -50, checking.Id, foreignAccount.Id, "EXTERNAL", now));
            await db.SaveChangesAsync();
            return new Fixture(db, owner, checking, foreignAccount);
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(),
            FirstName = name,
            LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com",
            PhoneNumber = "+38761000000",
            PasswordHash = "hash",
            Role = AppRoles.Customer,
            Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string number, string currency, decimal balance) => new()
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            User = user,
            AccountNumber = number,
            Currency = currency,
            Balance = balance,
            AccountType = AccountType.Checking,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Transaction Transaction(
            Account account,
            decimal amount,
            Guid sourceId,
            Guid destinationId,
            string reference,
            DateTime createdAtUtc) => new()
        {
            Id = Guid.NewGuid(),
            AccountId = account.Id,
            Account = account,
            SourceAccountId = sourceId,
            DestinationAccountId = destinationId,
            ReferenceNumber = reference,
            Amount = amount,
            Description = "Transfer",
            Status = TransactionStatus.Completed,
            CreatedAtUtc = createdAtUtc
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
