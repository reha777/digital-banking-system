using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions.Risk;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class TransactionRiskServiceTests
{
    private static readonly TransactionRiskFeatures LowFeatures =
        new(0.01, 0.05, 0, 0, 0, 0, 0);
    private static readonly TransactionRiskFeatures HighFeatures =
        new(1.5, 1.2, 1.5, 1.2, 2, 1, 1);

    [Fact]
    public void Probability_is_bounded_and_deterministic()
    {
        var first = TransactionRiskLogisticModel.Probability(LowFeatures);
        var second = TransactionRiskLogisticModel.Probability(LowFeatures);
        var extreme = TransactionRiskLogisticModel.Probability(
            new TransactionRiskFeatures(3, 2, 2, 3, 3, 1, 2));

        Assert.InRange(first, 0m, 1m);
        Assert.InRange(extreme, 0m, 1m);
        Assert.Equal(first, second);
    }

    [Fact]
    public void Riskier_feature_vector_has_higher_probability_and_crosses_threshold()
    {
        var low = TransactionRiskLogisticModel.Probability(LowFeatures);
        var high = TransactionRiskLogisticModel.Probability(HighFeatures);

        Assert.True(high > low);
        Assert.True(low < 0.60m);
        Assert.True(high >= 0.60m);
    }

    [Fact]
    public void Velocity_new_recipient_and_adverse_history_each_increase_probability()
    {
        var baseline = TransactionRiskLogisticModel.Probability(LowFeatures);
        var velocity = TransactionRiskLogisticModel.Probability(LowFeatures with
        {
            OutgoingVelocity24Hours = 1
        });
        var newRecipient = TransactionRiskLogisticModel.Probability(LowFeatures with
        {
            NewRecipient = 1
        });
        var adverse = TransactionRiskLogisticModel.Probability(LowFeatures with
        {
            AdverseHistory30Days = 1
        });

        Assert.True(velocity > baseline);
        Assert.True(newRecipient > baseline);
        Assert.True(adverse > baseline);
    }

    [Fact]
    public async Task Same_amount_has_different_probability_for_different_context()
    {
        await using var fixture = await Fixture.CreateAsync();
        var now = DateTime.UtcNow;
        fixture.AddOutgoing(fixture.SafeSource, fixture.SafeDestination.Id, 10000, now.AddDays(-2),
            TransactionStatus.Completed);
        for (var index = 0; index < 5; index++)
            fixture.AddOutgoing(fixture.RiskySource, Guid.NewGuid(), 1000, now.AddMinutes(-index - 1),
                TransactionStatus.Pending);
        for (var index = 0; index < 3; index++)
            fixture.AddOutgoing(fixture.RiskySource, Guid.NewGuid(), 500, now.AddDays(-index - 10),
                TransactionStatus.Failed, highRisk: true);
        await fixture.Db.SaveChangesAsync();

        var safe = await fixture.EvaluateAsync(
            fixture.SafeSource, fixture.SafeDestination, 10000, 100000, now);
        var risky = await fixture.EvaluateAsync(
            fixture.RiskySource, fixture.RiskyDestination, 10000, 11000, now);

        Assert.Equal(0, safe.Features.NewRecipient);
        Assert.Equal(1, risky.Features.NewRecipient);
        Assert.True(risky.Features.OutgoingVelocity24Hours > safe.Features.OutgoingVelocity24Hours);
        Assert.True(risky.Features.AdverseHistory30Days > safe.Features.AdverseHistory30Days);
        Assert.True(risky.Probability > safe.Probability);
        Assert.False(safe.IsHighRisk);
        Assert.True(risky.IsHighRisk);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Account safeSource, Account riskySource,
            Account safeDestination, Account riskyDestination)
        {
            Db = db;
            SafeSource = safeSource;
            RiskySource = riskySource;
            SafeDestination = safeDestination;
            RiskyDestination = riskyDestination;
            Service = new TransactionRiskService(
                db,
                new DemoCurrencyConversionService(),
                Options.Create(new TransactionRiskOptions()));
        }

        public BankingAppDbContext Db { get; }
        public Account SafeSource { get; }
        public Account RiskySource { get; }
        public Account SafeDestination { get; }
        public Account RiskyDestination { get; }
        public TransactionRiskService Service { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var safeOwner = User("Safe");
            var riskyOwner = User("Risky");
            var recipient = User("Recipient");
            var safeSource = Account(safeOwner, "SAFE-SOURCE");
            var riskySource = Account(riskyOwner, "RISKY-SOURCE");
            var safeDestination = Account(recipient, "SAFE-DESTINATION");
            var riskyDestination = Account(recipient, "RISKY-DESTINATION");
            db.Users.AddRange(safeOwner, riskyOwner, recipient);
            db.Accounts.AddRange(safeSource, riskySource, safeDestination, riskyDestination);
            await db.SaveChangesAsync();
            return new Fixture(db, safeSource, riskySource, safeDestination, riskyDestination);
        }

        public void AddOutgoing(Account source, Guid destinationId, decimal amount, DateTime created,
            TransactionStatus status, bool highRisk = false) => Db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = source.Id, SourceAccountId = source.Id,
            DestinationAccountId = destinationId, ReferenceNumber = Guid.NewGuid().ToString("N"),
            Amount = -amount, TransferAmount = amount, TransferCurrency = "BAM",
            Type = TransactionType.Transfer, Description = "History", Status = status,
            IsHighRiskReview = highRisk, CreatedAtUtc = created
        });

        public Task<TransactionRiskResult> EvaluateAsync(Account source, Account destination,
            decimal amount, decimal balance, DateTime now) => Service.EvaluateAsync(
                new TransactionRiskContext(source.UserId, source.Id, destination.Id, amount, "BAM",
                    amount, amount, balance, now));

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = "Customer", Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string number) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = number,
            AccountTypeId = BankingApp.Domain.Constants.AccountTypeCodes.CheckingId, Status = AccountStatus.Active,
            Balance = 100000, Currency = "BAM", CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
}
