using BankingApp.Application.AuditLogs;
using BankingApp.Application.Cards;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Professor item 10: the final admin approval must revalidate the business
/// preconditions against the current state of the system, not against the state
/// that was valid when the request was created.
/// </summary>
public sealed class ApprovalCurrentStateTests
{
    // ---------- transaction approval ----------

    [Fact]
    public async Task Valid_pending_transfer_is_approved_and_posted()
    {
        await using var f = await TransferFixture.CreateAsync();

        var response = await f.AdminService().ApproveReviewAsync(
            f.Transaction.Id, new TransactionReviewRequest { AdminNote = "Looks fine" });

        Assert.Equal(TransactionStatus.Completed, response.Status);
        Assert.Equal(900m, (await f.SourceAsync()).Balance);
        Assert.Equal(1100m, (await f.DestinationAsync()).Balance);
        Assert.Contains(f.Audit.Records, record => record.Action == AuditLogActions.TransactionApproved);
        Assert.Contains(f.Notifications.Sent, sent => sent.Type == NotificationType.TransactionApproved);
    }

    [Fact]
    public async Task Source_account_closed_after_the_request_blocks_approval()
    {
        await using var f = await TransferFixture.CreateAsync();
        (await f.SourceAsync()).Status = AccountStatus.Closed;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Source account is no longer active.");
    }

    [Fact]
    public async Task Destination_account_closed_after_the_request_blocks_approval()
    {
        await using var f = await TransferFixture.CreateAsync();
        (await f.DestinationAsync()).Status = AccountStatus.Closed;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Destination account is no longer active.");
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Source_customer_deactivated_or_deleted_blocks_approval(bool deleted)
    {
        await using var f = await TransferFixture.CreateAsync();
        var owner = await f.Db.Users.SingleAsync(user => user.Id == f.Owner.Id);
        if (deleted) { owner.IsDeleted = true; owner.DeletedAtUtc = DateTime.UtcNow; }
        else owner.Status = CustomerStatus.Inactive;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Source customer is no longer active.");
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Destination_customer_deactivated_or_deleted_blocks_approval(bool deleted)
    {
        await using var f = await TransferFixture.CreateAsync();
        var recipient = await f.Db.Users.SingleAsync(user => user.Id == f.Recipient.Id);
        if (deleted) { recipient.IsDeleted = true; recipient.DeletedAtUtc = DateTime.UtcNow; }
        else recipient.Status = CustomerStatus.Inactive;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Destination customer is no longer active.");
    }

    [Fact]
    public async Task Balance_spent_after_the_request_blocks_approval()
    {
        await using var f = await TransferFixture.CreateAsync();
        (await f.SourceAsync()).Balance = 50m;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Source balance is no longer sufficient.", expectedSourceBalance: 50m);
    }

    [Fact]
    public async Task Account_currency_changed_after_the_request_blocks_approval()
    {
        await using var f = await TransferFixture.CreateAsync();
        (await f.DestinationAsync()).Currency = SupportedCurrencies.Eur;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync(
            "Account currencies no longer match the transaction.",
            expectedDestinationBalance: 1000m);
    }

    [Fact]
    public async Task Already_final_transaction_cannot_be_approved_again()
    {
        await using var f = await TransferFixture.CreateAsync();
        var service = f.AdminService();
        await service.ApproveReviewAsync(f.Transaction.Id, new TransactionReviewRequest());

        await Assert.ThrowsAsync<BusinessException>(() =>
            service.ApproveReviewAsync(f.Transaction.Id, new TransactionReviewRequest()));

        // The first approval posted exactly once.
        Assert.Equal(900m, (await f.SourceAsync()).Balance);
        Assert.Equal(1100m, (await f.DestinationAsync()).Balance);
    }

    // ---------- card approval ----------

    [Fact]
    public async Task Active_customer_with_active_checking_type_is_approved()
    {
        await using var f = await CardFixture.CreateAsync();

        var approved = await f.AdminService().ApproveAsync(
            f.Request.Id, new CardRequestReviewRequest { AdminNote = "ok" });

        Assert.Equal(CardRequestStatus.Approved, approved.Status);
        Assert.NotNull(approved.IssuedCard);
        Assert.Matches("^[0-9]{4}$", approved.IssuedCard!.OneTimeCvv);
        Assert.Equal(1, await f.Db.Accounts.CountAsync(a => a.UserId == f.Customer.Id));
        Assert.Equal(1, await f.Db.BankCards.CountAsync());
        Assert.Contains(f.Audit.Records, record => record.Action == AuditLogActions.CardRequestApproved);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Customer_deactivated_or_deleted_after_the_request_blocks_card_approval(bool deleted)
    {
        await using var f = await CardFixture.CreateAsync();
        var customer = await f.Db.Users.SingleAsync(user => user.Id == f.Customer.Id);
        if (deleted) { customer.IsDeleted = true; customer.DeletedAtUtc = DateTime.UtcNow; }
        else customer.Status = CustomerStatus.Inactive;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Customer is no longer active");
    }

    [Fact]
    public async Task Checking_type_deactivated_after_the_request_blocks_card_approval()
    {
        await using var f = await CardFixture.CreateAsync();
        var checking = await f.Db.AccountTypeDefinitions
            .SingleAsync(value => value.Id == AccountTypeCodes.CheckingId);
        checking.IsActive = false;
        await f.Db.SaveChangesAsync();

        await f.AssertApprovalRejectedAsync("Active CHECKING account type is not configured.");
    }

    [Fact]
    public async Task Already_reviewed_card_request_cannot_be_approved_again()
    {
        await using var f = await CardFixture.CreateAsync();
        var service = f.AdminService();
        await service.ApproveAsync(f.Request.Id, new CardRequestReviewRequest());

        await Assert.ThrowsAsync<BusinessException>(() =>
            service.ApproveAsync(f.Request.Id, new CardRequestReviewRequest()));

        // Exactly one account and one card were issued.
        Assert.Equal(1, await f.Db.Accounts.CountAsync(a => a.UserId == f.Customer.Id));
        Assert.Equal(1, await f.Db.BankCards.CountAsync());
    }

    // ---------- fixtures ----------

    private sealed class TransferFixture : IAsyncDisposable
    {
        private TransferFixture(BankingAppDbContext db, User owner, User recipient, User admin,
            Account source, Account destination, Transaction transaction)
        {
            Db = db; Owner = owner; Recipient = recipient; Admin = admin;
            Source = source; Destination = destination; Transaction = transaction;
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User Recipient { get; }
        public User Admin { get; }
        public Account Source { get; }
        public Account Destination { get; }
        public Transaction Transaction { get; }
        public CapturingAudit Audit { get; } = new();
        public CapturingNotifications Notifications { get; } = new();

        public TransactionService AdminService() => new(
            Db, new CurrentUser(Admin.Id, true), new DemoCurrencyConversionService(),
            Audit, null, Notifications);

        public Task<Account> SourceAsync() => Db.Accounts.SingleAsync(a => a.Id == Source.Id);
        public Task<Account> DestinationAsync() => Db.Accounts.SingleAsync(a => a.Id == Destination.Id);

        public async Task AssertApprovalRejectedAsync(
            string expectedMessage,
            decimal expectedSourceBalance = 1000m,
            decimal expectedDestinationBalance = 1000m)
        {
            var error = await Assert.ThrowsAsync<BusinessException>(() =>
                AdminService().ApproveReviewAsync(Transaction.Id, new TransactionReviewRequest()));
            Assert.Equal(expectedMessage, error.Message);

            Db.ChangeTracker.Clear();
            // No money moved and the transfer stays in its review state.
            Assert.Equal(expectedSourceBalance, (await SourceAsync()).Balance);
            Assert.Equal(expectedDestinationBalance, (await DestinationAsync()).Balance);
            var reread = await Db.Transactions.SingleAsync(value => value.Id == Transaction.Id);
            Assert.Equal(TransactionStatus.Pending, reread.Status);
            Assert.Null(reread.ReviewedAtUtc);
            Assert.Equal(1, await Db.Transactions.CountAsync());
            // No misleading "approved" trail.
            Assert.DoesNotContain(Audit.Records, r => r.Action == AuditLogActions.TransactionApproved);
            Assert.DoesNotContain(Notifications.Sent, s => s.Type == NotificationType.TransactionApproved);
        }

        public static async Task<TransferFixture> CreateAsync()
        {
            var db = NewContext();
            db.SeedAccountTypes();
            var owner = TestUser("Owner", AppRoles.Customer);
            var recipient = TestUser("Recipient", AppRoles.Customer);
            var admin = TestUser("Admin", AppRoles.Admin);
            var source = TestAccount(owner, "BA-SOURCE-CHECKING", 1000m);
            var destination = TestAccount(recipient, "BA-DEST-CHECKING", 1000m);
            var transaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = source.Id,
                SourceAccountId = source.Id,
                DestinationAccountId = destination.Id,
                ReferenceNumber = "TRX-REVIEW-1",
                Amount = -100m,
                Type = TransactionType.Transfer,
                TransactionCategoryId = ReferenceDataIds.TransferTransactionCategory,
                TransferAmount = 100m,
                TransferCurrency = SupportedCurrencies.Bam,
                DestinationAmount = 100m,
                Description = "High risk transfer",
                Status = TransactionStatus.Pending,
                IsHighRiskReview = true,
                CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(owner, recipient, admin);
            db.Accounts.AddRange(source, destination);
            db.Transactions.Add(transaction);
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();
            return new TransferFixture(db, owner, recipient, admin, source, destination, transaction);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CardFixture : IAsyncDisposable
    {
        private CardFixture(BankingAppDbContext db, User customer, User admin, CardRequest request)
        {
            Db = db; Customer = customer; Admin = admin; Request = request;
        }

        public BankingAppDbContext Db { get; }
        public User Customer { get; }
        public User Admin { get; }
        public CardRequest Request { get; }
        public CapturingAudit Audit { get; } = new();
        public CapturingNotifications Notifications { get; } = new();

        public CardService AdminService() =>
            new(Db, new CurrentUser(Admin.Id, true), Audit, null, Notifications);

        public async Task AssertApprovalRejectedAsync(string expectedMessageFragment)
        {
            var error = await Assert.ThrowsAsync<BusinessException>(() =>
                AdminService().ApproveAsync(Request.Id, new CardRequestReviewRequest()));
            Assert.Contains(expectedMessageFragment, error.Message, StringComparison.Ordinal);

            Db.ChangeTracker.Clear();
            // Nothing was issued and the request stays reviewable.
            Assert.Equal(0, await Db.Accounts.CountAsync());
            Assert.Equal(0, await Db.BankCards.CountAsync());
            var reread = await Db.CardRequests.SingleAsync(value => value.Id == Request.Id);
            Assert.Equal(CardRequestStatus.Pending, reread.Status);
            Assert.Null(reread.ApprovedAccountId);
            Assert.Null(reread.ApprovedCardId);
            Assert.Null(reread.ReviewedAtUtc);
            Assert.DoesNotContain(Audit.Records, r => r.Action == AuditLogActions.CardRequestApproved);
            Assert.DoesNotContain(Notifications.Sent, s => s.Type == NotificationType.CardRequestApproved);
        }

        public static async Task<CardFixture> CreateAsync()
        {
            var db = NewContext();
            db.SeedAccountTypes();
            var customer = TestUser("Card", AppRoles.Customer);
            var admin = TestUser("Admin", AppRoles.Admin);
            var request = new CardRequest
            {
                Id = Guid.NewGuid(),
                UserId = customer.Id,
                User = customer,
                CardholderName = "Card Customer",
                Currency = SupportedCurrencies.Bam,
                DocumentNumber = "ID-1",
                DeliveryAddress = "Street 1",
                Note = string.Empty,
                Status = CardRequestStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(customer, admin);
            db.CardRequests.Add(request);
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();
            return new CardFixture(db, customer, admin, request);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private static BankingAppDbContext NewContext() =>
        new(new DbContextOptionsBuilder<BankingAppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static User TestUser(string name, string role) => new()
    {
        Id = Guid.NewGuid(),
        FirstName = name,
        LastName = "User",
        Email = $"{Guid.NewGuid()}@example.com",
        PhoneNumber = "+38761000000",
        PasswordHash = "hash",
        Role = role,
        Status = CustomerStatus.Active,
        CreatedAtUtc = DateTime.UtcNow
    };

    private static Account TestAccount(User user, string number, decimal balance) => new()
    {
        Id = Guid.NewGuid(),
        UserId = user.Id,
        User = user,
        AccountNumber = number,
        AccountTypeId = AccountTypeCodes.CheckingId,
        Currency = SupportedCurrencies.Bam,
        Balance = balance,
        Status = AccountStatus.Active,
        CreatedAtUtc = DateTime.UtcNow
    };

    private sealed class CurrentUser(Guid id, bool admin = false) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => admin;
    }

    private sealed class CapturingAudit : IAuditLogService
    {
        public List<AuditLogRecordRequest> Records { get; } = [];
        public Task RecordAsync(AuditLogRecordRequest request, CancellationToken token = default)
        {
            Records.Add(request);
            return Task.CompletedTask;
        }
        public Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken token = default) =>
            throw new NotSupportedException();
    }

    private sealed class CapturingNotifications : INotificationWriter
    {
        public List<NotificationCreate> Sent { get; } = [];
        public Task AddAsync(NotificationCreate notification, CancellationToken cancellationToken = default)
        {
            Sent.Add(notification);
            return Task.CompletedTask;
        }
        public Task AddForAdminsAsync(NotificationCreate notification, CancellationToken cancellationToken = default)
        {
            Sent.Add(notification);
            return Task.CompletedTask;
        }
    }
}
