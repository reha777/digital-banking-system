using BankingApp.Application.Interfaces;
using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using BankingApp.Api.Controllers;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class RecentRecipientTests
{
    [Fact]
    public void Transaction_routes_require_authentication() =>
        Assert.NotEmpty(typeof(TransactionsController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true));

    [Fact]
    public async Task Current_customer_receives_unique_recipients_in_last_used_order()
    {
        await using var fixture = await RecipientFixture.CreateAsync(withTransfers: true);
        var result = await fixture.Service.GetRecentRecipientsAsync(new PagedRequest());

        Assert.Equal(2, result.TotalCount);
        Assert.Equal("recipient-a", result.Items.First().AccountNumber);
        Assert.DoesNotContain(result.Items, item => item.AccountNumber == "unrelated-recipient");
    }

    [Fact]
    public async Task Customer_without_transfers_receives_empty_list()
    {
        await using var fixture = await RecipientFixture.CreateAsync(withTransfers: false);
        Assert.Empty((await fixture.Service.GetRecentRecipientsAsync(new PagedRequest())).Items);
    }

    [Fact]
    public async Task Recent_recipients_support_page_two_with_stable_recent_order()
    {
        await using var fixture = await RecipientFixture.CreateAsync(withTransfers: true);
        var first = await fixture.Service.GetRecentRecipientsAsync(
            new PagedRequest { PageSize = 1 });
        var second = await fixture.Service.GetRecentRecipientsAsync(
            new PagedRequest { Page = 2, PageSize = 1 });

        Assert.Equal(2, first.TotalCount);
        Assert.Equal(2, first.TotalPages);
        Assert.Equal("recipient-a", first.Items.Single().AccountNumber);
        Assert.Equal("recipient-b", second.Items.Single().AccountNumber);
    }

    [Fact]
    public async Task Lookup_returns_backend_verified_owner_name()
    {
        await using var fixture = await RecipientFixture.CreateAsync(withTransfers: false);
        var result = await fixture.Service.LookupRecipientAsync("recipient-a");
        Assert.Equal("Alice", result.FirstName);
        Assert.Equal("Recipient", result.LastName);
    }

    private sealed class RecipientFixture : IAsyncDisposable
    {
        private RecipientFixture(BankingAppDbContext db, Guid userId)
        {
            Db = db;
            Service = new TransactionService(db, new CurrentUser(userId), new DemoCurrencyConversionService());
        }
        public BankingAppDbContext Db { get; }
        public TransactionService Service { get; }

        public static async Task<RecipientFixture> CreateAsync(bool withTransfers)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner", "Customer");
            var alice = User("Alice", "Recipient");
            var bob = User("Bob", "Recipient");
            var unrelatedOwner = User("Other", "Sender");
            var source = Account(owner, "source");
            var recipientA = Account(alice, "recipient-a");
            var recipientB = Account(bob, "recipient-b");
            var unrelatedSource = Account(unrelatedOwner, "unrelated-source");
            var unrelatedRecipient = Account(bob, "unrelated-recipient");
            db.Users.AddRange(owner, alice, bob, unrelatedOwner);
            db.Accounts.AddRange(source, recipientA, recipientB, unrelatedSource, unrelatedRecipient);
            if (withTransfers)
            {
                db.Transactions.AddRange(
                    Transfer(source, recipientA, DateTime.UtcNow.AddMinutes(-1)),
                    Transfer(source, recipientB, DateTime.UtcNow.AddMinutes(-2)),
                    Transfer(source, recipientA, DateTime.UtcNow.AddMinutes(-3)),
                    Transfer(unrelatedSource, unrelatedRecipient, DateTime.UtcNow));
            }
            await db.SaveChangesAsync();
            return new RecipientFixture(db, owner.Id);
        }

        private static User User(string first, string last) => new()
        {
            Id = Guid.NewGuid(), FirstName = first, LastName = last,
            Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string number) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user,
            AccountNumber = number, Currency = "USD", Balance = 1000,
            AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow
        };

        private static Transaction Transfer(Account source, Account destination, DateTime at) => new()
        {
            Id = Guid.NewGuid(), AccountId = source.Id, Account = source,
            SourceAccountId = source.Id, DestinationAccountId = destination.Id,
            ReferenceNumber = Guid.NewGuid().ToString(), Amount = -10,
            Description = "Transfer", Status = TransactionStatus.Completed,
            CreatedAtUtc = at
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
