using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class LoanRecommendationTests
{
    [Fact]
    public async Task Returns_only_active_products_matching_customer_currency_and_top_three()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddProduct("EUR", 3, true);
        fixture.AddProduct("BAM", 9, false);
        fixture.AddProduct("BAM", 8, true);
        fixture.AddProduct("BAM", 7, true);
        fixture.AddProduct("BAM", 6, true);
        fixture.AddProduct("BAM", 5, true);
        await fixture.Db.SaveChangesAsync();

        var response = await fixture.Service.GetRecommendationsAsync();

        Assert.True(response.CanApply);
        Assert.Equal(3, response.Recommendations.Count);
        Assert.All(response.Recommendations, item => Assert.Equal("BAM", item.Currency));
        Assert.Equal([1, 2, 3], response.Recommendations.Select(item => item.Rank));
        Assert.All(response.Recommendations, item => Assert.InRange(item.Score, 0, 100));
    }

    [Fact]
    public async Task Lower_interest_rate_wins_deterministically_when_other_signals_match()
    {
        await using var fixture = await Fixture.CreateAsync();
        var expensive = fixture.AddProduct("BAM", 8, true, "Expensive");
        var affordable = fixture.AddProduct("BAM", 4, true, "Affordable");
        await fixture.Db.SaveChangesAsync();

        var first = await fixture.Service.GetRecommendationsAsync();
        var second = await fixture.Service.GetRecommendationsAsync();

        Assert.Equal(affordable.Id, first.Recommendations.First().ProductId);
        Assert.Equal(
            first.Recommendations.Select(item => item.ProductId),
            second.Recommendations.Select(item => item.ProductId));
        Assert.DoesNotContain(first.Recommendations, item => item.ProductId == expensive.Id && item.Rank == 1);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Active_loan_or_pending_application_blocks_recommendations(bool activeLoan)
    {
        await using var fixture = await Fixture.CreateAsync();
        var product = fixture.AddProduct("BAM", 5, true);
        if (activeLoan) fixture.AddActiveLoan(product);
        else fixture.AddPendingApplication(product);
        await fixture.Db.SaveChangesAsync();

        var response = await fixture.Service.GetRecommendationsAsync();

        Assert.False(response.CanApply);
        Assert.Empty(response.Recommendations);
        Assert.NotNull(response.BlockReason);
    }

    [Fact]
    public async Task Activity_is_isolated_by_customer_and_currency()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddProduct("BAM", 5, true);
        fixture.AddCompletedIncoming(fixture.OwnerAccount, 200);
        fixture.AddCompletedIncoming(fixture.ForeignAccount, 10000);
        await fixture.Db.SaveChangesAsync();

        var response = await fixture.Service.GetRecommendationsAsync();

        var recommendation = Assert.Single(response.Recommendations);
        Assert.Contains(recommendation.Reasons, reason => reason.Contains("activity"));
        Assert.InRange(recommendation.Score, 0, 100);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, Account ownerAccount, Account foreignAccount)
        {
            Db = db;
            Owner = owner;
            OwnerAccount = ownerAccount;
            ForeignAccount = foreignAccount;
            Service = new LoanRecommendationService(db, new CurrentUser(owner.Id));
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public Account OwnerAccount { get; }
        public Account ForeignAccount { get; }
        public LoanRecommendationService Service { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var foreign = User("Foreign");
            var ownerAccount = Account(owner, "BAM");
            var foreignAccount = Account(foreign, "BAM");
            db.AddRange(owner, foreign, ownerAccount, foreignAccount);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, ownerAccount, foreignAccount);
        }

        public LoanProduct AddProduct(string currency, decimal rate, bool active, string? name = null)
        {
            var product = new LoanProduct
            {
                Id = Guid.NewGuid(), Name = name ?? $"{currency} {Guid.NewGuid():N}", Currency = currency,
                Description = "Test", MinPrincipal = 500, MaxPrincipal = 10000,
                AnnualInterestRate = rate, MinTermMonths = 6, MaxTermMonths = 36,
                TermStepMonths = 6, IsActive = active, CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            };
            Db.LoanProducts.Add(product);
            return product;
        }

        public void AddPendingApplication(LoanProduct product) => Db.LoanApplications.Add(new LoanApplication
        {
            Id = Guid.NewGuid(), UserId = Owner.Id, LoanProductId = product.Id,
            DestinationAccountId = OwnerAccount.Id, Principal = 1000, Currency = "BAM",
            AnnualInterestRateSnapshot = product.AnnualInterestRate, TermMonths = 12,
            EstimatedMonthlyPayment = 90, EstimatedTotalInterest = 80,
            EstimatedTotalRepayment = 1080, Status = LoanApplicationStatus.Pending,
            SubmittedAtUtc = DateTime.UtcNow, ClientRequestId = Guid.NewGuid()
        });

        public void AddActiveLoan(LoanProduct product)
        {
            AddPendingApplication(product);
            var application = Db.LoanApplications.Local.Last();
            application.Status = LoanApplicationStatus.Approved;
            Db.Loans.Add(new Loan
            {
                Id = Guid.NewGuid(), LoanApplicationId = application.Id, UserId = Owner.Id,
                DestinationAccountId = OwnerAccount.Id, OriginalPrincipal = 1000,
                OutstandingPrincipal = 1000, Currency = "BAM", AnnualInterestRate = 5,
                TermMonths = 12, MonthlyPayment = 90, TotalRepayment = 1080,
                Status = LoanStatus.Active, StartDateUtc = DateTime.UtcNow,
                NextPaymentDateUtc = DateTime.UtcNow.AddMonths(1),
                MaturityDateUtc = DateTime.UtcNow.AddYears(1), CreatedAtUtc = DateTime.UtcNow
            });
        }

        public void AddCompletedIncoming(Account account, decimal amount) => Db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
            ReferenceNumber = Guid.NewGuid().ToString("N"), Amount = amount,
            Description = "Incoming", Status = TransactionStatus.Completed,
            CreatedAtUtc = DateTime.UtcNow
        });

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
            Balance = 100, AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
