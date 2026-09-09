using BankingApp.Application.AuditLogs;
using BankingApp.Application.Cards;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Domain.Services;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Professor item 9: the CVV must not be a persisted, retrievable value, and
/// security-relevant values must come from a cryptographic RNG.
/// </summary>
public sealed class SecureCardDataTests
{
    [Fact]
    public void Card_model_and_contracts_expose_no_cvv()
    {
        Assert.Null(typeof(BankCard).GetProperty("Cvv"));
        Assert.Null(typeof(CardResponse).GetProperty("Cvv"));
        Assert.Null(typeof(CardSensitiveDataResponse).GetProperty("Cvv"));

        // The only place a CVV may appear is the one-time issue result.
        Assert.NotNull(typeof(CardIssueResult).GetProperty("OneTimeCvv"));
    }

    [Fact]
    public async Task Persistence_model_has_no_cvv_column()
    {
        await using var fixture = await Fixture.CreateAsync();

        var card = fixture.Db.Model.FindEntityType(typeof(BankCard));

        Assert.NotNull(card);
        Assert.DoesNotContain(card!.GetProperties(), property => property.Name == "Cvv");
        // The columns that must survive the migration.
        Assert.Contains(card.GetProperties(), property => property.Name == nameof(BankCard.CardNumber));
        Assert.Contains(card.GetProperties(), property => property.Name == nameof(BankCard.ExpiryDate));
        Assert.Contains(card.GetProperties(), property => property.Name == nameof(BankCard.Status));
        Assert.Contains(card.GetProperties(), property => property.Name == nameof(BankCard.AccountId));
    }

    [Fact]
    public async Task Approval_returns_a_one_time_cvv_that_is_never_persisted()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.AdminService();
        var request = await fixture.PendingRequestAsync();

        var approved = await service.ApproveAsync(request.Id, new CardRequestReviewRequest { AdminNote = "Approved" });

        var issued = approved.IssuedCard;
        Assert.NotNull(issued);
        Assert.Equal(approved.ApprovedCardId, issued!.CardId);
        Assert.Matches("^[0-9]{4}$", issued.OneTimeCvv);
        Assert.Matches("^4562[0-9]{12}$", issued.CardNumber);
        Assert.InRange(issued.ExpiryMonth, 1, 12);
        Assert.Equal(DateTime.UtcNow.Year + 4, issued.ExpiryYear);
        Assert.Contains("only once", issued.Warning, StringComparison.OrdinalIgnoreCase);

        // Nothing anywhere in the stored card row carries the code.
        var stored = await fixture.Db.BankCards.AsNoTracking().SingleAsync(value => value.Id == issued.CardId);
        Assert.Equal(issued.CardNumber, stored.CardNumber);
        Assert.DoesNotContain(
            fixture.Db.Model.FindEntityType(typeof(BankCard))!.GetProperties(),
            property => property.Name.Contains("Cvv", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Cvv_never_reaches_audit_notifications_or_later_reads()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.AdminService();
        var request = await fixture.PendingRequestAsync();

        var approved = await service.ApproveAsync(request.Id, new CardRequestReviewRequest { AdminNote = "Approved" });
        var cvv = approved.IssuedCard!.OneTimeCvv;

        Assert.DoesNotContain(fixture.Audit.Records, record =>
            Contains(record.Description, cvv) || Contains(record.Reason, cvv) ||
            Contains(record.OldValue, cvv) || Contains(record.NewValue, cvv));
        Assert.DoesNotContain(fixture.Notifications.Sent, sent =>
            Contains(sent.Title, cvv) || Contains(sent.Message, cvv));

        // Reading the request back afterwards never carries the issue result again.
        var reread = await service.GetRequestsAsync(new CardRequestQueryRequest { Page = 1, PageSize = 20 });
        Assert.All(reread.Items, item => Assert.Null(item.IssuedCard));

        var issuedCard = await service.GetIssuedCardAsync(approved.ApprovedCardId!.Value);
        Assert.Null(issuedCard.GetType().GetProperty("Cvv"));
    }

    [Fact]
    public async Task Sensitive_data_returns_number_and_expiry_but_no_cvv()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.OwnerService();

        var sensitive = await service.GetSensitiveDataAsync(fixture.ExistingCard.Id);

        Assert.Equal(fixture.ExistingCard.Id, sensitive.Id);
        Assert.Equal(fixture.ExistingCard.CardNumber, sensitive.CardNumber);
        Assert.Equal(fixture.ExistingCard.ExpiryDate, sensitive.ExpiryDate);
        Assert.Null(sensitive.GetType().GetProperty("Cvv"));
    }

    [Fact]
    public async Task Customer_cannot_read_another_customers_sensitive_data()
    {
        await using var fixture = await Fixture.CreateAsync();
        var intruder = new CardService(fixture.Db, new CurrentUser(fixture.Other.Id));

        await Assert.ThrowsAsync<NotFoundException>(() =>
            intruder.GetSensitiveDataAsync(fixture.ExistingCard.Id));
    }

    [Fact]
    public async Task Existing_cards_survive_cvv_removal_and_still_read_back()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.OwnerService();

        var cards = await service.GetMyCardsAsync(new PagedRequest { Page = 1, PageSize = 20 });

        var card = Assert.Single(cards.Items);
        Assert.Equal(fixture.ExistingCard.Id, card.Id);
        Assert.Equal("**** **** **** " + fixture.ExistingCard.CardNumber[^4..], card.MaskedCardNumber);
        Assert.Equal(CardStatus.Active, card.Status);
        Assert.Equal(fixture.ExistingCard.ExpiryDate, card.ExpiryDate);
        Assert.Equal(fixture.OwnerAccount.Id, card.AccountId);
    }

    [Fact]
    public async Task Issued_numbers_keep_their_format_and_stay_unique()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.AdminService();
        var numbers = new List<string>();

        for (var index = 0; index < 5; index++)
        {
            var request = await fixture.PendingRequestAsync();
            var approved = await service.ApproveAsync(request.Id, new CardRequestReviewRequest());
            numbers.Add(approved.IssuedCard!.CardNumber);

            // Item 8: the issued account still resolves CHECKING from reference data.
            var account = await fixture.Db.Accounts.Include(value => value.AccountTypeDefinition)
                .SingleAsync(value => value.Id == approved.ApprovedAccountId);
            Assert.Equal(AccountTypeCodes.Checking, account.AccountTypeDefinition.Code);
            Assert.Equal(
                AccountNumberGenerator.Create(account.Id, AccountTypeCodes.Checking),
                account.AccountNumber);
        }

        Assert.All(numbers, number => Assert.Matches("^4562[1-9][0-9]{11}$", number));
        Assert.Equal(numbers.Count, numbers.Distinct().Count());
    }

    [Fact]
    public void Secure_generator_produces_the_requested_digit_shape()
    {
        Assert.Matches("^[0-9]{11}$", SecureIdentifierGenerator.NewDigits(11));
        Assert.Equal(4, SecureIdentifierGenerator.NewDigits(4).Length);
        Assert.Throws<ArgumentOutOfRangeException>(() => SecureIdentifierGenerator.NewDigits(0));

        var first = SecureIdentifierGenerator.NewGuid();
        Assert.NotEqual(Guid.Empty, first);
        Assert.NotEqual(first, SecureIdentifierGenerator.NewGuid());
        Assert.Equal('4', first.ToString()[14]); // RFC 4122 version 4 nibble
    }

    private static bool Contains(string? value, string cvv) =>
        value is not null && value.Contains(cvv, StringComparison.Ordinal);

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User other, User admin, Account ownerAccount, BankCard existingCard)
        {
            Db = db; Owner = owner; Other = other; Admin = admin;
            OwnerAccount = ownerAccount; ExistingCard = existingCard;
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User Other { get; }
        public User Admin { get; }
        public Account OwnerAccount { get; }
        public BankCard ExistingCard { get; }
        public CapturingAudit Audit { get; } = new();
        public CapturingNotifications Notifications { get; } = new();

        public CardService AdminService() =>
            new(Db, new CurrentUser(Admin.Id, true), Audit, null, Notifications);

        public CardService OwnerService() => new(Db, new CurrentUser(Owner.Id));

        public async Task<CardRequest> PendingRequestAsync()
        {
            var request = new CardRequest
            {
                Id = Guid.NewGuid(),
                UserId = Owner.Id,
                User = Owner,
                CardholderName = "Owner Customer",
                Currency = "USD",
                DocumentNumber = "ID-1",
                DeliveryAddress = "Street 1",
                Note = string.Empty,
                Status = CardRequestStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow
            };
            Db.CardRequests.Add(request);
            await Db.SaveChangesAsync();
            return request;
        }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            db.SeedAccountTypes();
            var owner = User("Owner", AppRoles.Customer);
            var other = User("Other", AppRoles.Customer);
            var admin = User("Admin", AppRoles.Admin);
            var account = new Account
            {
                Id = Guid.NewGuid(),
                UserId = owner.Id,
                User = owner,
                AccountNumber = "BA-EXISTING-CHECKING",
                AccountTypeId = AccountTypeCodes.CheckingId,
                Currency = "USD",
                Balance = 100,
                Status = AccountStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            var card = new BankCard
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                Account = account,
                CardNumber = "4562112245957852",
                CardholderName = "Owner Customer",
                ExpiryDate = new DateTime(2030, 6, 24, 0, 0, 0, DateTimeKind.Utc),
                Brand = CardBrand.Mastercard,
                Status = CardStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(owner, other, admin);
            db.Accounts.Add(account);
            db.BankCards.Add(card);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, other, admin, account, card);
        }

        private static User User(string name, string role) => new()
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

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

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
