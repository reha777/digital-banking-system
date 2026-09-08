using BankingApp.Api.Controllers;
using BankingApp.Application.Accounts;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Cards;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AdminAccountCardManagementTests
{
    [Fact]
    public void Admin_management_controllers_are_admin_only_and_expose_no_generic_mutation()
    {
        Assert.Equal(AppRoles.Admin, Assert.Single(typeof(AdminAccountsController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>()).Roles);
        Assert.Equal(AppRoles.Admin, Assert.Single(typeof(AdminCardsController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>()).Roles);
        Assert.DoesNotContain(typeof(AdminAccountsController).GetMethods(), method => method.Name is "Update" or "Delete");
        Assert.DoesNotContain(typeof(AdminCardsController).GetMethods(), method => method.Name is "Update" or "Delete");
    }

    [Fact]
    public async Task Admin_close_is_audited_preserves_history_and_blocks_linked_card()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Db.Transactions.Add(new Transaction { Id = Guid.NewGuid(), AccountId = fixture.Account.Id,
            ReferenceNumber = "ADMIN-CLOSE-HISTORY", Amount = 0, Type = TransactionType.Transfer,
            Status = TransactionStatus.Completed, Description = "History", CreatedAtUtc = DateTime.UtcNow });
        await fixture.Db.SaveChangesAsync();

        var result = await fixture.Accounts.CloseAsAdminAsync(fixture.Account.Id);

        Assert.Equal(AccountStatus.Closed, result.Status);
        Assert.Equal(CardStatus.Blocked, fixture.Card.Status);
        Assert.True(await fixture.Db.Transactions.AnyAsync(value => value.ReferenceNumber == "ADMIN-CLOSE-HISTORY"));
        Assert.Equal(AuditLogActions.AccountClosedByAdmin, Assert.Single(fixture.Audit.Records).Action);
    }

    [Fact]
    public async Task Admin_cannot_close_non_zero_account()
    {
        await using var fixture = await Fixture.CreateAsync(balance: 1);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Accounts.CloseAsAdminAsync(fixture.Account.Id));
        Assert.Equal(AccountStatus.Active, fixture.Account.Status);
    }

    [Fact]
    public async Task Admin_can_block_and_unblock_without_changing_card_identity()
    {
        await using var fixture = await Fixture.CreateAsync();
        var number = fixture.Card.CardNumber;
        await fixture.Cards.SetAdminCardStatusAsync(fixture.Card.Id, true);
        Assert.Equal(CardStatus.Blocked, fixture.Card.Status);
        await fixture.Cards.SetAdminCardStatusAsync(fixture.Card.Id, false);
        Assert.Equal(CardStatus.Active, fixture.Card.Status);
        Assert.Equal(number, fixture.Card.CardNumber);
        Assert.Equal(new[] { AuditLogActions.CardBlockedByAdmin, AuditLogActions.CardUnblockedByAdmin }, fixture.Audit.Records.Select(value => value.Action));
    }

    [Fact]
    public async Task Card_on_closed_account_cannot_be_unblocked()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Account.Status = AccountStatus.Closed;
        fixture.Card.Status = CardStatus.Blocked;
        await fixture.Db.SaveChangesAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Cards.SetAdminCardStatusAsync(fixture.Card.Id, false));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Account account, BankCard card, RecordingAudit audit)
        {
            Db = db; Account = account; Card = card; Audit = audit;
            var current = new CurrentUser(account.UserId);
            Accounts = new AccountService(db, current, audit);
            Cards = new CardService(db, current, audit);
        }
        public BankingAppDbContext Db { get; }
        public Account Account { get; }
        public BankCard Card { get; }
        public RecordingAudit Audit { get; }
        public AccountService Accounts { get; }
        public CardService Cards { get; }

        public static async Task<Fixture> CreateAsync(decimal balance = 0)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var user = new User { Id = Guid.NewGuid(), FirstName = "Demo", LastName = "Customer",
                Email = "demo@example.test", PhoneNumber = "+38761000000", PasswordHash = "hash",
                Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            var account = new Account { Id = Guid.NewGuid(), UserId = user.Id, User = user,
                AccountNumber = "BA-ADMIN-TEST", AccountType = AccountType.Checking,
                Status = AccountStatus.Active, Balance = balance, Currency = "EUR", CreatedAtUtc = DateTime.UtcNow };
            var card = new BankCard { Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
                CardNumber = "4562111122223333", CardholderName = "Demo Customer", Cvv = "123",
                Brand = CardBrand.Visa, Status = CardStatus.Active, ExpiryDate = DateTime.UtcNow.AddYears(2), CreatedAtUtc = DateTime.UtcNow };
            account.Card = card;
            db.AddRange(user, account, card); await db.SaveChangesAsync();
            return new Fixture(db, account, card, new RecordingAudit());
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => true; }
    private sealed class RecordingAudit : IAuditLogService
    {
        public List<AuditLogRecordRequest> Records { get; } = [];
        public Task RecordAsync(AuditLogRecordRequest request, CancellationToken cancellationToken = default) { Records.Add(request); return Task.CompletedTask; }
        public Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
