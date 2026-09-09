using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.AuditLogs;
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

public sealed class TopUpTests
{
    [Fact]
    public async Task Top_up_atomically_credits_balance_and_creates_one_ledger_audit_and_notification()
    {
        await using var fixture = await Fixture.CreateAsync();

        var result = await fixture.Service.TopUpAsync(fixture.Request(250m));

        Assert.Equal(TransactionType.TopUp, result.Type);
        Assert.Equal(TransactionStatus.Completed, result.Status);
        Assert.Equal(250m, result.Amount);
        Assert.Equal("USD", result.Currency);
        Assert.Equal("ExternalBankCard", result.TopUpSourceType);
        Assert.Equal("External card ending 1234", result.TopUpSourceDescription);
        Assert.Equal(1250m, (await fixture.Db.Accounts.FindAsync(fixture.Account.Id))!.Balance);
        var ledger = await fixture.Db.Transactions.SingleAsync();
        Assert.Equal(result.Id, ledger.Id);
        Assert.Null(ledger.SourceAccountId);
        Assert.Equal(fixture.Account.Id, ledger.DestinationAccountId);
        Assert.StartsWith("TOPUP-", ledger.ReferenceNumber);
        Assert.Equal(AuditLogActions.TopUpCompleted, (await fixture.Db.AuditLogs.SingleAsync()).Action);
        var notification = await fixture.Db.Notifications.SingleAsync();
        Assert.Equal(NotificationType.TopUpCompleted, notification.Type);
        Assert.Equal(fixture.Owner.Id, notification.UserId);
    }

    [Fact]
    public async Task Two_top_ups_and_retry_keep_balance_and_ledger_consistent()
    {
        await using var fixture = await Fixture.CreateAsync();
        var firstRequest = fixture.Request(250m);
        var first = await fixture.Service.TopUpAsync(firstRequest);
        var retry = await fixture.Service.TopUpAsync(firstRequest);
        await fixture.Service.TopUpAsync(fixture.Request(100m));

        Assert.Equal(first.Id, retry.Id);
        Assert.Equal(1350m, (await fixture.Db.Accounts.FindAsync(fixture.Account.Id))!.Balance);
        Assert.Equal(2, await fixture.Db.Transactions.CountAsync());
        Assert.Equal(2, await fixture.Db.AuditLogs.CountAsync());
        Assert.Equal(2, await fixture.Db.Notifications.CountAsync());
    }

    [Fact]
    public async Task Foreign_and_closed_accounts_are_rejected_without_balance_or_ledger_change()
    {
        await using var fixture = await Fixture.CreateAsync();
        var foreign = fixture.Request(100m); foreign.AccountId = fixture.ForeignAccount.Id;
        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Service.TopUpAsync(foreign));
        var ownedAccount = await fixture.Db.Accounts.SingleAsync(value => value.Id == fixture.Account.Id);
        ownedAccount.Status = AccountStatus.Closed;
        await fixture.Db.SaveChangesAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.TopUpAsync(fixture.Request(100m)));
        Assert.Equal(1000m, ownedAccount.Balance);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Fact]
    public async Task Admin_context_cannot_use_customer_top_up_operation()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new TransactionService(fixture.Db, new AdminUser(fixture.Owner.Id),
            new DemoCurrencyConversionService());

        await Assert.ThrowsAsync<BusinessException>(() => service.TopUpAsync(fixture.Request(100m)));
        Assert.Equal(1000m, fixture.Account.Balance);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Theory]
    [InlineData(0, "USD", "ExternalBankCard", "1234")]
    [InlineData(-1, "USD", "ExternalBankCard", "1234")]
    [InlineData(10001, "USD", "ExternalBankCard", "1234")]
    [InlineData(100.001, "USD", "ExternalBankCard", "1234")]
    [InlineData(100, "EUR", "ExternalBankCard", "1234")]
    [InlineData(100, "USD", "Unknown", "Safe source")]
    [InlineData(100, "USD", "ExternalBankCard", "123")]
    [InlineData(100, "USD", "ExternalBankCard", "12345")]
    [InlineData(100, "USD", "ExternalBankCard", "12A4")]
    public async Task Invalid_request_is_rejected_without_side_effects(
        decimal amount, string currency, string sourceType, string description)
    {
        await using var fixture = await Fixture.CreateAsync();
        var request = fixture.Request(amount);
        request.Currency = currency; request.SourceType = sourceType; request.SourceDescription = description;

        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.TopUpAsync(request));

        Assert.Equal(1000m, fixture.Account.Balance);
        Assert.Empty(fixture.Db.Transactions);
        Assert.Empty(fixture.Db.Notifications);
        Assert.Empty(fixture.Db.AuditLogs);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, Account account, Account foreignAccount, TransactionService service)
        { Db = db; Owner = owner; Account = account; ForeignAccount = foreignAccount; Service = service; }
        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public Account Account { get; }
        public Account ForeignAccount { get; }
        public TransactionService Service { get; }
        public TopUpRequest Request(decimal amount) => new()
        {
            AccountId = Account.Id, Amount = amount, Currency = "USD",
            SourceType = "ExternalBankCard", SourceDescription = "1234", ClientRequestId = Guid.NewGuid()
        };
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("owner@test.local"); var other = User("other@test.local");
            var account = MakeAccount(owner, "BA-TOPUP-OWNER", 1000m);
            var foreign = MakeAccount(other, "BA-TOPUP-OTHER", 500m);
            db.AddRange(owner, other, account, foreign); await db.SaveChangesAsync();
            var current = new CurrentUser(owner.Id);
            var service = new TransactionService(db, current, new DemoCurrencyConversionService(),
                new AuditLogService(db, current), notificationWriter: new NotificationWriter(db));
            return new Fixture(db, owner, account, foreign, service);
        }
        private static User User(string email) => new()
        {
            Id = Guid.NewGuid(), FirstName = "Top", LastName = "Up", Email = email,
            PhoneNumber = "+38761000000", PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };
        private static Account MakeAccount(User user, string number, decimal balance) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = number,
            AccountTypeId = BankingApp.Domain.Constants.AccountTypeCodes.CheckingId, Status = AccountStatus.Active,
            Balance = balance, Currency = "USD", CreatedAtUtc = DateTime.UtcNow
        };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id) : ICurrentUserService
    { public Guid UserId => id; public bool IsAdmin => false; }
    private sealed class AdminUser(Guid id) : ICurrentUserService
    { public Guid UserId => id; public bool IsAdmin => true; }
}
