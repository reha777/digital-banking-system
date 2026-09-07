using BankingApp.Api.Controllers;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Domain.Services;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AccountManagementHardeningTests
{
    [Fact]
    public void Generic_account_mutation_endpoints_are_not_exposed()
    {
        var actions = typeof(AccountsController).GetMethods()
            .Where(method => method.DeclaringType == typeof(AccountsController))
            .SelectMany(method => method.GetCustomAttributes(true)
                .OfType<HttpMethodAttribute>()
                .Select(attribute => (method.Name, attribute.HttpMethods, attribute.Template)))
            .ToList();

        Assert.DoesNotContain(actions, action =>
            action.HttpMethods.Contains("POST") && string.IsNullOrEmpty(action.Template));
        Assert.DoesNotContain(actions, action => action.HttpMethods.Contains("PUT"));
        Assert.DoesNotContain(actions, action => action.HttpMethods.Contains("DELETE"));

        var close = Assert.Single(actions, action => action.Name == nameof(AccountsController.Close));
        Assert.Equal("{id:guid}/close", close.Template);
        var authorization = Assert.Single(typeof(AccountsController).GetMethod(nameof(AccountsController.Close))!
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Customer, authorization.Roles);
    }

    [Fact]
    public void Account_write_contracts_cannot_accept_opening_balance_or_financial_identifiers()
    {
        var applicationAssembly = typeof(IAccountService).Assembly;

        Assert.Null(applicationAssembly.GetType("BankingApp.Application.Accounts.AccountCreateRequest"));
        Assert.Null(applicationAssembly.GetType("BankingApp.Application.Accounts.AccountUpdateRequest"));
        Assert.DoesNotContain(typeof(IAccountService).GetMethods(), method =>
            method.Name is "CreateAsync" or "UpdateAsync" or "DeleteAsync");
    }

    [Fact]
    public void Account_numbers_are_server_generated_deterministically_and_uniquely()
    {
        var firstId = Guid.Parse("11111111-2222-3333-4444-555555555555");
        var secondId = Guid.Parse("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");

        var first = AccountNumberGenerator.Create(firstId, AccountType.Checking);

        Assert.Equal(first, AccountNumberGenerator.Create(firstId, AccountType.Checking));
        Assert.StartsWith("BA-11111111222233334444-", first);
        Assert.EndsWith("-CHECKING", first);
        Assert.NotEqual(first, AccountNumberGenerator.Create(secondId, AccountType.Checking));
    }

    [Theory]
    [InlineData("USD")]
    [InlineData("EUR")]
    [InlineData("BAM")]
    [InlineData("usd")]
    public void Supported_currency_catalog_accepts_only_configured_values(string currency)
    {
        Assert.True(SupportedCurrencies.IsSupported(currency));
        Assert.Equal(currency.ToUpperInvariant(), SupportedCurrencies.Normalize(currency));
        Assert.False(SupportedCurrencies.IsSupported("GBP"));
    }

    [Fact]
    public async Task Closing_is_owned_soft_delete_and_preserves_history()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = fixture.Account.Id,
            ReferenceNumber = "HISTORY-1", Amount = 0,
            Type = TransactionType.Transfer, Status = TransactionStatus.Completed,
            Description = "Historical entry", CreatedAtUtc = DateTime.UtcNow
        });
        await fixture.Db.SaveChangesAsync();

        var response = await fixture.Service.CloseAsync(fixture.Account.Id);

        Assert.Equal(AccountStatus.Closed, response.Status);
        Assert.Equal(AccountStatus.Closed, (await fixture.Db.Accounts.SingleAsync()).Status);
        Assert.Equal("HISTORY-1", (await fixture.Db.Transactions.SingleAsync()).ReferenceNumber);
        Assert.Empty((await fixture.Service.GetBalanceSummaryAsync()).Accounts);
        await Assert.ThrowsAsync<NotFoundException>(() =>
            new AccountService(fixture.Db, new CurrentUser(fixture.OtherUser.Id))
                .CloseAsync(fixture.Account.Id));
    }

    [Fact]
    public async Task Non_zero_balance_account_cannot_be_closed()
    {
        await using var fixture = await Fixture.CreateAsync(balance: 1);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.CloseAsync(fixture.Account.Id));
        Assert.Equal(AccountStatus.Active, fixture.Account.Status);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User otherUser, Account account)
        {
            Db = db;
            OtherUser = otherUser;
            Account = account;
            Service = new AccountService(db, new CurrentUser(owner.Id));
        }

        public BankingAppDbContext Db { get; }
        public User OtherUser { get; }
        public Account Account { get; }
        public AccountService Service { get; }

        public static async Task<Fixture> CreateAsync(decimal balance = 0)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var other = User("Other");
            var account = new Account
            {
                Id = Guid.NewGuid(), UserId = owner.Id, User = owner,
                AccountNumber = "BA-TEST-CHECKING", AccountType = AccountType.Checking,
                Status = AccountStatus.Active, Balance = balance, Currency = SupportedCurrencies.Usd,
                CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(owner, other);
            db.Accounts.Add(account);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, other, account);
        }

        private static User User(string firstName) => new()
        {
            Id = Guid.NewGuid(), FirstName = firstName, LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
