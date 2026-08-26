using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class LoanApplicationTests
{
    [Theory]
    [InlineData("BAM", 1000)]
    [InlineData("EUR", 500)]
    [InlineData("USD", 500)]
    public async Task Valid_application_uses_authenticated_owner_and_backend_snapshot(string currency, decimal principal)
    {
        await using var fixture = await Fixture.CreateAsync();
        var product = fixture.Products.Single(value => value.Currency == currency);
        var account = fixture.Accounts.Single(value => value.Currency == currency);
        var before = DateTime.UtcNow;

        var result = await fixture.Service.SubmitApplicationAsync(fixture.Request(product, account, principal));
        var stored = await fixture.Db.LoanApplications.SingleAsync();

        Assert.Equal(fixture.Owner.Id, stored.UserId);
        Assert.Equal(LoanApplicationStatus.Pending, result.Status);
        Assert.Equal(product.AnnualInterestRate, stored.AnnualInterestRateSnapshot);
        Assert.Equal(result.EstimatedMonthlyPayment, stored.EstimatedMonthlyPayment);
        Assert.Equal(result.EstimatedTotalInterest, stored.EstimatedTotalInterest);
        Assert.Equal(result.EstimatedTotalRepayment, stored.EstimatedTotalRepayment);
        Assert.InRange(stored.SubmittedAtUtc, before, DateTime.UtcNow);
        Assert.Null(stored.ReviewedAtUtc);
        Assert.Null(stored.ReviewedByUserId);
        Assert.Null(stored.AdminNote);
    }

    [Fact]
    public async Task Foreign_destination_account_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.ForeignAccount, 1000)));
    }

    [Fact]
    public async Task Currency_mismatch_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.Accounts.Single(value => value.Currency == "EUR"), 1000)));
    }

    [Theory]
    [InlineData(499, 6)]
    [InlineData(25001, 6)]
    [InlineData(1000, 7)]
    [InlineData(1000, 66)]
    public async Task Invalid_principal_or_term_is_rejected(decimal principal, int term)
    {
        await using var fixture = await Fixture.CreateAsync();
        var request = fixture.Request(fixture.Usd, fixture.UsdAccount, principal);
        request.TermMonths = term;
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(request));
    }

    [Fact]
    public async Task Inactive_product_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Inactive, fixture.UsdAccount, 1000)));
    }

    [Fact]
    public async Task Active_loan_purpose_is_stored_and_inactive_purpose_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var active = new ReferenceDataItem { Id = Guid.NewGuid(), Type = "loan-purposes", Code = "HOME", Name = "Home", IsActive = true, SortOrder = 1, CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow };
        var inactive = new ReferenceDataItem { Id = Guid.NewGuid(), Type = "loan-purposes", Code = "OLD", Name = "Old", IsActive = false, SortOrder = 2, CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow };
        fixture.Db.ReferenceDataItems.AddRange(active, inactive);
        await fixture.Db.SaveChangesAsync();
        var valid = fixture.Request(fixture.Usd, fixture.UsdAccount, 1000);
        valid.LoanPurposeId = active.Id;
        var result = await fixture.Service.SubmitApplicationAsync(valid);
        Assert.Equal(active.Id, result.LoanPurposeId);
        Assert.Equal("Home", result.LoanPurposeName);

        fixture.Db.LoanApplications.RemoveRange(fixture.Db.LoanApplications);
        await fixture.Db.SaveChangesAsync();
        var invalid = fixture.Request(fixture.Usd, fixture.UsdAccount, 1000);
        invalid.LoanPurposeId = inactive.Id;
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(invalid));
    }

    [Fact]
    public async Task Same_idempotency_key_returns_existing_but_conflicting_payload_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var request = fixture.Request(fixture.Usd, fixture.UsdAccount, 1000);
        var first = await fixture.Service.SubmitApplicationAsync(request);
        var retry = await fixture.Service.SubmitApplicationAsync(request);

        Assert.Equal(first.Id, retry.Id);
        Assert.Equal(1, await fixture.Db.LoanApplications.CountAsync());
        request.Principal = 1200;
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(request));
    }

    [Fact]
    public async Task Existing_pending_application_blocks_new_request()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.SubmitApplicationAsync(fixture.Request(fixture.Usd, fixture.UsdAccount, 1000));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.UsdAccount, 1200)));
    }

    [Fact]
    public async Task Active_loan_blocks_new_application()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.AddActiveLoanAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.UsdAccount, 1000)));
    }

    [Fact]
    public async Task Rejected_previous_application_allows_new_application()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Db.LoanApplications.Add(fixture.Application(LoanApplicationStatus.Rejected, Guid.NewGuid()));
        await fixture.Db.SaveChangesAsync();

        var result = await fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.UsdAccount, 1000));

        Assert.Equal(LoanApplicationStatus.Pending, result.Status);
        Assert.Equal(2, await fixture.Db.LoanApplications.CountAsync());
    }

    [Fact]
    public async Task Current_returns_owned_pending_before_latest_reviewed()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Db.LoanApplications.Add(fixture.Application(LoanApplicationStatus.Rejected, Guid.NewGuid()));
        fixture.Db.LoanApplications.Add(fixture.ForeignApplication());
        await fixture.Db.SaveChangesAsync();
        var pending = await fixture.Service.SubmitApplicationAsync(
            fixture.Request(fixture.Usd, fixture.UsdAccount, 1000));

        var current = await fixture.Service.GetCurrentApplicationAsync();

        Assert.NotNull(current);
        Assert.Equal(pending.Id, current.Id);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(
            BankingAppDbContext db,
            LoanService service,
            User owner,
            User foreign,
            List<LoanProduct> products,
            LoanProduct inactive,
            List<Account> accounts,
            Account foreignAccount)
        {
            Db = db; Service = service; Owner = owner; Foreign = foreign;
            Products = products; Inactive = inactive; Accounts = accounts; ForeignAccount = foreignAccount;
        }

        public BankingAppDbContext Db { get; }
        public LoanService Service { get; }
        public User Owner { get; }
        public User Foreign { get; }
        public List<LoanProduct> Products { get; }
        public LoanProduct Inactive { get; }
        public List<Account> Accounts { get; }
        public Account ForeignAccount { get; }
        public LoanProduct Usd => Products.Single(value => value.Currency == "USD");
        public Account UsdAccount => Accounts.Single(value => value.Currency == "USD");

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var foreign = User("Foreign");
            var products = new List<LoanProduct>
            {
                Product("BAM", 1000, 50000, 6.5m), Product("EUR", 500, 25000, 5.75m), Product("USD", 500, 25000, 6m)
            };
            var inactive = Product("USD", 500, 25000, 7m, false);
            var accounts = products.Select(value => Account(owner, value.Currency)).ToList();
            var foreignAccount = Account(foreign, "USD");
            db.AddRange(owner, foreign);
            db.LoanProducts.AddRange(products.Append(inactive));
            db.Accounts.AddRange(accounts.Append(foreignAccount));
            await db.SaveChangesAsync();
            return new Fixture(db, new LoanService(db, new CurrentUser(owner.Id), new LoanCalculationService()),
                owner, foreign, products, inactive, accounts, foreignAccount);
        }

        public LoanApplicationCreateRequest Request(LoanProduct product, Account account, decimal principal) => new()
        {
            LoanProductId = product.Id,
            DestinationAccountId = account.Id,
            Principal = principal,
            TermMonths = 6,
            ClientRequestId = Guid.NewGuid()
        };

        public LoanApplication Application(LoanApplicationStatus status, Guid requestId) => new()
        {
            Id = Guid.NewGuid(), UserId = Owner.Id, LoanProductId = Usd.Id, DestinationAccountId = UsdAccount.Id,
            Principal = 1000, Currency = "USD", AnnualInterestRateSnapshot = 6, TermMonths = 6,
            EstimatedMonthlyPayment = 170, EstimatedTotalInterest = 20, EstimatedTotalRepayment = 1020,
            Status = status, SubmittedAtUtc = DateTime.UtcNow.AddDays(-2), ReviewedAtUtc = DateTime.UtcNow.AddDays(-1),
            ClientRequestId = requestId
        };

        public LoanApplication ForeignApplication() => new()
        {
            Id = Guid.NewGuid(), UserId = Foreign.Id, LoanProductId = Usd.Id, DestinationAccountId = ForeignAccount.Id,
            Principal = 1000, Currency = "USD", AnnualInterestRateSnapshot = 6, TermMonths = 6,
            EstimatedMonthlyPayment = 170, EstimatedTotalInterest = 20, EstimatedTotalRepayment = 1020,
            Status = LoanApplicationStatus.Pending, SubmittedAtUtc = DateTime.UtcNow, ClientRequestId = Guid.NewGuid()
        };

        public async Task AddActiveLoanAsync()
        {
            var application = Application(LoanApplicationStatus.Approved, Guid.NewGuid());
            Db.LoanApplications.Add(application);
            Db.Loans.Add(new Loan
            {
                Id = Guid.NewGuid(), LoanApplicationId = application.Id, UserId = Owner.Id,
                DestinationAccountId = UsdAccount.Id, OriginalPrincipal = 1000, OutstandingPrincipal = 1000,
                Currency = "USD", AnnualInterestRate = 6, TermMonths = 6, MonthlyPayment = 170,
                TotalRepayment = 1020, TotalPaid = 0, StartDateUtc = DateTime.UtcNow,
                NextPaymentDateUtc = DateTime.UtcNow.AddMonths(1), MaturityDateUtc = DateTime.UtcNow.AddMonths(6),
                Status = LoanStatus.Active, CreatedAtUtc = DateTime.UtcNow
            });
            await Db.SaveChangesAsync();
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "Customer", Email = $"{Guid.NewGuid()}@test.local",
            PhoneNumber = "+38761000000", PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string currency) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = $"BA-{Guid.NewGuid():N}",
            AccountType = AccountType.Checking, Balance = 100, Currency = currency, CreatedAtUtc = DateTime.UtcNow
        };

        private static LoanProduct Product(string currency, decimal min, decimal max, decimal rate, bool active = true) => new()
        {
            Id = Guid.NewGuid(), Name = $"Personal Loan {currency}", Description = "Test", Currency = currency,
            MinPrincipal = min, MaxPrincipal = max, AnnualInterestRate = rate, MinTermMonths = 6,
            MaxTermMonths = 60, TermStepMonths = 6, IsActive = active,
            CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
