using BankingApp.Application.Customers;
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

public class CurrencyCorrectnessTests
{
    [Fact]
    public async Task Customer_balances_are_grouped_by_currency()
    {
        await using var fixture = await Fixture.CreateAsync();
        var customer = Assert.Single((await new AdminCustomerService(
            fixture.Db, new UserSessionRevocationService(fixture.Db))
            .GetAsync(new CustomerQueryRequest())).Items);

        Assert.Equal(3, customer.Balances.Count);
        Assert.Equal(150m, customer.Balances.Single(item => item.Currency == "USD").Amount);
        Assert.Equal(200m, customer.Balances.Single(item => item.Currency == "EUR").Amount);
        Assert.Equal(300m, customer.Balances.Single(item => item.Currency == "BAM").Amount);
    }

    [Fact]
    public async Task Transaction_volume_is_grouped_by_account_currency()
    {
        await using var fixture = await Fixture.CreateAsync();
        var summary = await fixture.TransactionService.GetSummaryAsync(new TransactionQueryRequest());

        Assert.Equal(3, summary.TransferredByCurrency.Count);
        Assert.Equal(10m, summary.TransferredByCurrency.Single(item => item.Currency == "USD").Amount);
        Assert.Equal(20m, summary.TransferredByCurrency.Single(item => item.Currency == "EUR").Amount);
        Assert.Equal(30m, summary.TransferredByCurrency.Single(item => item.Currency == "BAM").Amount);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User admin)
        {
            Db = db;
            TransactionService = new TransactionService(db, new CurrentUser(admin.Id), new DemoCurrencyConversionService());
        }
        public BankingAppDbContext Db { get; }
        public TransactionService TransactionService { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var customer = User("Customer", AppRoles.Customer);
            var admin = User("Admin", AppRoles.Admin);
            var usdOne = Account(customer, "usd-1", "USD", 100);
            var usdTwo = Account(customer, "usd-2", "USD", 50);
            var eur = Account(customer, "eur", "EUR", 200);
            var bam = Account(customer, "bam", "BAM", 300);
            db.Users.AddRange(customer, admin);
            db.Accounts.AddRange(usdOne, usdTwo, eur, bam);
            db.Transactions.AddRange(
                Transaction(usdOne, -10), Transaction(eur, -20), Transaction(bam, -30));
            await db.SaveChangesAsync();
            return new Fixture(db, admin);
        }

        private static User User(string name, string role) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "User",
            Email = $"{Guid.NewGuid()}@test.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = role, Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };
        private static Account Account(User user, string number, string currency, decimal balance) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = number,
            Currency = currency, Balance = balance, AccountType = AccountType.Checking,
            CreatedAtUtc = DateTime.UtcNow
        };
        private static Transaction Transaction(Account account, decimal amount) => new()
        {
            Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
            ReferenceNumber = Guid.NewGuid().ToString(), Amount = amount,
            Type = TransactionType.Transfer, Description = "Test",
            Status = TransactionStatus.Completed, CreatedAtUtc = DateTime.UtcNow
        };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => true;
    }
}
