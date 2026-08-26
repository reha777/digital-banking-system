using BankingApp.Application.Common.Exceptions;
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

public class CustomerLifecycleSecurityTests
{
    [Theory]
    [InlineData(CustomerStatus.Blocked, false)]
    [InlineData(CustomerStatus.Inactive, false)]
    [InlineData(CustomerStatus.Active, true)]
    public async Task Central_guard_uses_semantic_customer_lifecycle(
        CustomerStatus status,
        bool expected)
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Sender.Status = status;
        await fixture.Db.SaveChangesAsync();

        var validator = new CustomerAccessValidator(fixture.Db);

        Assert.Equal(expected, await validator.IsActiveCustomerAsync(fixture.Sender.Id));
    }

    [Fact]
    public async Task Central_guard_rejects_soft_deleted_customer()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Sender.IsDeleted = true;
        await fixture.Db.SaveChangesAsync();

        Assert.False(await new CustomerAccessValidator(fixture.Db)
            .IsActiveCustomerAsync(fixture.Sender.Id));
    }

    [Fact]
    public async Task Blocking_customer_revokes_refresh_tokens_permanently()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new AdminCustomerService(
            fixture.Db,
            new UserSessionRevocationService(fixture.Db));

        await service.UpdateStatusAsync(fixture.Sender.Id,
            new CustomerStatusUpdateRequest { Status = CustomerStatus.Blocked });
        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);

        await service.UpdateStatusAsync(fixture.Sender.Id,
            new CustomerStatusUpdateRequest { Status = CustomerStatus.Active });
        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);
        Assert.False(fixture.RefreshToken.IsActive);
    }

    [Fact]
    public async Task Soft_delete_revokes_refresh_token_and_guard_rejects_old_context()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new AdminCustomerService(
            fixture.Db,
            new UserSessionRevocationService(fixture.Db));

        await service.DeleteAsync(fixture.Sender.Id);

        Assert.True(fixture.Sender.IsDeleted);
        Assert.Equal(CustomerStatus.Inactive, fixture.Sender.Status);
        Assert.False(fixture.RefreshToken.IsActive);
        Assert.False(await new CustomerAccessValidator(fixture.Db)
            .IsActiveCustomerAsync(fixture.Sender.Id));
    }

    [Theory]
    [InlineData(CustomerStatus.Blocked, false)]
    [InlineData(CustomerStatus.Inactive, false)]
    [InlineData(CustomerStatus.Active, true)]
    public async Task Recipient_lookup_only_returns_active_non_deleted_customer(
        CustomerStatus status,
        bool succeeds)
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Recipient.Status = status;
        await fixture.Db.SaveChangesAsync();

        var action = () => fixture.Transactions.LookupRecipientAsync(
            fixture.Destination.AccountNumber);

        if (succeeds)
            Assert.Equal(fixture.Destination.Id, (await action()).AccountId);
        else
            await Assert.ThrowsAsync<NotFoundException>(action);
    }

    [Fact]
    public async Task Recipient_soft_delete_blocks_quote_and_final_without_balance_change()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Recipient.IsDeleted = true;
        await fixture.Db.SaveChangesAsync();
        var sourceBefore = fixture.Source.Balance;
        var destinationBefore = fixture.Destination.Balance;

        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Transactions.QuoteAsync(
            fixture.Quote()));
        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Transactions.SendMoneyAsync(
            fixture.Transfer()));

        Assert.Equal(sourceBefore, fixture.Source.Balance);
        Assert.Equal(destinationBefore, fixture.Destination.Balance);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Fact]
    public async Task Recipient_blocked_after_quote_blocks_final_transfer_atomically()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Transactions.QuoteAsync(fixture.Quote());
        fixture.Recipient.Status = CustomerStatus.Blocked;
        await fixture.Db.SaveChangesAsync();
        var sourceBefore = fixture.Source.Balance;
        var destinationBefore = fixture.Destination.Balance;

        await Assert.ThrowsAsync<NotFoundException>(() =>
            fixture.Transactions.SendMoneyAsync(fixture.Transfer()));

        Assert.Equal(sourceBefore, fixture.Source.Balance);
        Assert.Equal(destinationBefore, fixture.Destination.Balance);
        Assert.Empty(fixture.Db.Transactions);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User sender, User recipient,
            Account source, Account destination, RefreshToken refreshToken)
        {
            Db = db;
            Sender = sender;
            Recipient = recipient;
            Source = source;
            Destination = destination;
            RefreshToken = refreshToken;
            Transactions = new TransactionService(
                db,
                new CurrentUser(sender.Id),
                new DemoCurrencyConversionService());
        }

        public BankingAppDbContext Db { get; }
        public User Sender { get; }
        public User Recipient { get; }
        public Account Source { get; }
        public Account Destination { get; }
        public RefreshToken RefreshToken { get; }
        public TransactionService Transactions { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var sender = User("sender@example.com");
            var recipient = User("recipient@example.com");
            var source = Account(sender, "SRC-001", 1000m);
            var destination = Account(recipient, "DST-001", 100m);
            var refresh = new RefreshToken
            {
                Id = Guid.NewGuid(), UserId = sender.Id, User = sender,
                TokenHash = Guid.NewGuid().ToString(), CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddDays(1)
            };
            db.AddRange(sender, recipient, source, destination, refresh);
            await db.SaveChangesAsync();
            return new Fixture(db, sender, recipient, source, destination, refresh);
        }

        public MoneyTransferQuoteRequest Quote() => new()
        {
            SourceAccountId = Source.Id,
            DestinationAccountNumber = Destination.AccountNumber,
            Amount = 25m,
            Currency = "USD"
        };

        public MoneyTransferRequest Transfer() => new()
        {
            SourceAccountId = Source.Id,
            DestinationAccountNumber = Destination.AccountNumber,
            Amount = 25m,
            Currency = "USD",
            Description = "Lifecycle test"
        };

        private static User User(string email) => new()
        {
            Id = Guid.NewGuid(), FirstName = "Test", LastName = "Customer",
            Email = email, PhoneNumber = "+38761000000", PasswordHash = "hash",
            Role = AppRoles.Customer, Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string number, decimal balance) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user,
            AccountNumber = number, AccountType = AccountType.Checking,
            Balance = balance, Currency = "USD", CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
