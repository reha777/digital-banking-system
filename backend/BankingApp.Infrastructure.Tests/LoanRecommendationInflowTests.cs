using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Professor item 12: the recommender's inflow signal must represent real incoming
/// money. A positive ledger credit is not enough — self-transfers and loan
/// disbursements produce one without the customer earning anything.
/// </summary>
public sealed class LoanRecommendationInflowTests
{
    private const int InflowWeight = 15;

    [Fact]
    public async Task A_self_transfer_between_own_accounts_does_not_count_as_inflow()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        // 500 moved from the customer's checking to their own savings: net worth unchanged.
        f.AddInternalTransferPair(f.OwnerAccount, f.OwnerSavings, 500m);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task A_self_transfer_typed_as_a_standard_transfer_is_also_excluded()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        // Ownership decides, not just the type label.
        f.AddTransferPair(f.OwnerAccount, f.OwnerSavings, 500m, TransactionType.Transfer);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task An_incoming_transfer_from_another_customer_counts_as_inflow()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 300m, TransactionType.Transfer);
        await f.SaveAsync();

        Assert.True(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task An_outgoing_transfer_is_never_treated_as_inflow_for_the_sender()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddTransferPair(f.OwnerAccount, f.ForeignAccount, 300m, TransactionType.Transfer);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task A_loan_disbursement_does_not_count_as_inflow()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        // Borrowed money must not make the recommender offer more borrowing.
        f.AddSingleRow(f.OwnerAccount, 1000m, TransactionType.LoanDisbursement);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task A_top_up_keeps_its_existing_exclusion_from_the_signal()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        // Self-service funding with no counterparty; excluded before this change too.
        f.AddSingleRow(f.OwnerAccount, 200m, TransactionType.TopUp);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task A_loan_repayment_debit_is_not_inflow()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddSingleRow(f.OwnerAccount, -60m, TransactionType.LoanRepayment);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task Mixed_activity_counts_only_the_genuine_external_inflow()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 300m, TransactionType.Transfer);
        f.AddInternalTransferPair(f.OwnerAccount, f.OwnerSavings, 500m);
        f.AddSingleRow(f.OwnerAccount, 1000m, TransactionType.LoanDisbursement);
        f.AddSingleRow(f.OwnerAccount, 200m, TransactionType.TopUp);
        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 400m, TransactionType.Transfer,
            TransactionStatus.Pending);
        await f.SaveAsync();

        // Only the 300 external transfer qualifies, never the 2400 gross credit total.
        Assert.Equal(300m, await f.QualifyingInflowAsync());
        Assert.True(await f.HasInflowReasonAsync());
    }

    [Theory]
    [InlineData(TransactionStatus.Pending, 0)]
    [InlineData(TransactionStatus.Failed, 0)]
    [InlineData(TransactionStatus.Completed, 1)]
    public async Task Only_completed_incoming_transfers_qualify(TransactionStatus status, int expected)
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 300m, TransactionType.Transfer, status);
        await f.SaveAsync();

        Assert.Equal(expected == 1, await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task Inflow_older_than_the_ninety_day_window_is_ignored()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 300m, TransactionType.Transfer,
            createdAtUtc: DateTime.UtcNow.AddDays(-91));
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());

        f.AddTransferPair(f.ForeignAccount, f.OwnerAccount, 300m, TransactionType.Transfer,
            createdAtUtc: DateTime.UtcNow.AddDays(-89));
        await f.SaveAsync();

        Assert.True(await f.HasInflowReasonAsync());
    }

    [Fact]
    public async Task An_internal_transfer_leaves_the_score_identical_while_real_income_raises_it()
    {
        // A 5000 self-transfer between the customer's own accounts.
        await using var selfTransfer = await Fixture.CreateAsync();
        selfTransfer.AddProduct();
        selfTransfer.AddInternalTransferPair(
            selfTransfer.OwnerAccount, selfTransfer.OwnerSavings, 5000m);
        await selfTransfer.SaveAsync();

        // 5000 genuinely received from another customer.
        await using var incoming = await Fixture.CreateAsync();
        incoming.AddProduct();
        incoming.AddTransferPair(
            incoming.ForeignAccount, incoming.OwnerAccount, 5000m, TransactionType.Transfer);
        await incoming.SaveAsync();

        // 5000 sent to another customer. This leaves the customer exactly one ledger row
        // on their own account, just like the incoming case, so the two scores differ only
        // by the inflow component — no score is hardcoded, the existing weights decide it.
        await using var outgoing = await Fixture.CreateAsync();
        outgoing.AddProduct();
        outgoing.AddTransferPair(
            outgoing.OwnerAccount, outgoing.ForeignAccount, 5000m, TransactionType.Transfer);
        await outgoing.SaveAsync();

        // Moving your own money buys no inflow credit; real income does.
        Assert.False(await selfTransfer.HasInflowReasonAsync());
        Assert.False(await outgoing.HasInflowReasonAsync());
        Assert.True(await incoming.HasInflowReasonAsync());

        var incomingScore = await incoming.TopScoreAsync();
        Assert.Equal(InflowWeight, incomingScore - await outgoing.TopScoreAsync());
        // The self-transfer still counts as account activity, but never as income.
        Assert.True(await selfTransfer.TopScoreAsync() < incomingScore);
    }

    [Fact]
    public async Task Taking_a_loan_does_not_feed_back_into_a_higher_recommendation()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddProduct();
        await f.SaveAsync();
        var before = await f.TopScoreAsync();

        // The customer receives a disbursement, then the recommender runs again.
        f.AddSingleRow(f.OwnerAccount, 5000m, TransactionType.LoanDisbursement);
        await f.SaveAsync();

        Assert.False(await f.HasInflowReasonAsync());
        Assert.True(await f.TopScoreAsync() < before + InflowWeight);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, Account ownerAccount,
            Account ownerSavings, Account foreignAccount)
        {
            Db = db; Owner = owner; OwnerAccount = ownerAccount;
            OwnerSavings = ownerSavings; ForeignAccount = foreignAccount;
            Service = new LoanRecommendationService(db, new CurrentUser(owner.Id));
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public Account OwnerAccount { get; }
        public Account OwnerSavings { get; }
        public Account ForeignAccount { get; }
        public LoanRecommendationService Service { get; }

        public async Task<bool> HasInflowReasonAsync()
        {
            var response = await Service.GetRecommendationsAsync();
            return response.Recommendations
                .Any(item => item.Reasons.Any(reason => reason.Contains("external inflows")));
        }

        public async Task<int> TopScoreAsync() =>
            (await Service.GetRecommendationsAsync()).Recommendations.First().Score;

        /// <summary>The inflow the service would score, computed with the shared rule.</summary>
        public async Task<decimal> QualifyingInflowAsync()
        {
            var sinceUtc = DateTime.UtcNow.AddDays(-90);
            var ownAccountIds = await Db.Accounts.AsNoTracking()
                .Where(account => account.UserId == Owner.Id)
                .Select(account => account.Id)
                .ToListAsync();
            return await Db.Transactions.AsNoTracking()
                .Where(t => t.Account.UserId == Owner.Id && t.CreatedAtUtc >= sinceUtc)
                .Where(BankingApp.Domain.Services.LoanRecommendationInflowRules.QualifyingCreditLeg)
                .Where(BankingApp.Domain.Services.LoanRecommendationInflowRules
                    .FromExternalCounterparty(ownAccountIds))
                .SumAsync(t => t.Amount);
        }

        public void AddProduct() => Db.LoanProducts.Add(new LoanProduct
        {
            Id = Guid.NewGuid(), Name = "Personal", Currency = "BAM",
            MinPrincipal = 100, MaxPrincipal = 10000, AnnualInterestRate = 5,
            MinTermMonths = 6, MaxTermMonths = 24, TermStepMonths = 1, IsActive = true
        });

        public void AddInternalTransferPair(Account source, Account destination, decimal amount) =>
            AddTransferPair(source, destination, amount, TransactionType.InternalTransfer);

        public void AddTransferPair(
            Account source,
            Account destination,
            decimal amount,
            TransactionType type,
            TransactionStatus status = TransactionStatus.Completed,
            DateTime? createdAtUtc = null)
        {
            var reference = Guid.NewGuid().ToString("N");
            var createdAt = createdAtUtc ?? DateTime.UtcNow;
            Db.Transactions.Add(Row(source, reference, -amount, type, status, createdAt,
                source.Id, destination.Id));
            Db.Transactions.Add(Row(destination, reference, amount, type, status, createdAt,
                source.Id, destination.Id));
        }

        public void AddSingleRow(Account account, decimal amount, TransactionType type) =>
            Db.Transactions.Add(Row(account, Guid.NewGuid().ToString("N"), amount, type,
                TransactionStatus.Completed, DateTime.UtcNow,
                amount < 0 ? account.Id : null, amount < 0 ? null : account.Id));

        private static Transaction Row(
            Account account, string reference, decimal amount, TransactionType type,
            TransactionStatus status, DateTime createdAtUtc,
            Guid? sourceAccountId, Guid? destinationAccountId) => new()
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                Account = account,
                SourceAccountId = sourceAccountId,
                DestinationAccountId = destinationAccountId,
                ReferenceNumber = reference,
                Amount = amount,
                Type = type,
                Description = "Test",
                Status = status,
                CreatedAtUtc = createdAtUtc
            };

        public Task SaveAsync() => Db.SaveChangesAsync();

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var foreign = User("Foreign");
            var ownerAccount = Account(owner, "BAM");
            var ownerSavings = Account(owner, "BAM");
            var foreignAccount = Account(foreign, "BAM");
            db.Users.AddRange(owner, foreign);
            db.Accounts.AddRange(ownerAccount, ownerSavings, foreignAccount);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, ownerAccount, ownerSavings, foreignAccount);
        }

        private static User User(string firstName) => new()
        {
            Id = Guid.NewGuid(), FirstName = firstName, LastName = "Customer",
            Email = $"{Guid.NewGuid()}@test.local", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string currency) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user,
            AccountNumber = Guid.NewGuid().ToString("N"), Currency = currency,
            Balance = 100, AccountTypeId = AccountTypeCodes.CheckingId,
            Status = AccountStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
