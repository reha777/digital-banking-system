using BankingApp.Application.Loans;
using BankingApp.Application.Messaging;
using BankingApp.Application.Reports;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace BankingApp.Worker.Tests;

/// <summary>
/// Professor item 15: OverdueOnly must be a database predicate applied before the
/// report row limit, so a report is never rejected because of loans the filter was
/// about to discard.
/// </summary>
public sealed class LoanReportFilterTests
{
    private const int MaxRows = 5;

    [Fact]
    public async Task Overdue_only_report_succeeds_even_when_all_loans_exceed_the_limit()
    {
        await using var f = await Fixture.CreateAsync();
        // Well over the limit in total...
        f.AddLoans(count: 12, overdue: false);
        // ...but only a handful actually belong in the report.
        f.AddLoans(count: 3, overdue: true);
        await f.SaveAsync();

        var rows = await f.GenerateAsync(overdueOnly: true);

        Assert.Equal(3, rows.Count);
        Assert.All(rows, row => Assert.True(row.IsOverdue));
    }

    [Fact]
    public async Task Overdue_only_report_is_still_rejected_when_the_overdue_set_is_too_large()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddLoans(count: 8, overdue: true);
        await f.SaveAsync();

        var error = await Assert.ThrowsAsync<InvalidOperationException>(
            () => f.GenerateAsync(overdueOnly: true));

        Assert.Contains("maximum", error.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Without_the_filter_the_limit_still_applies_to_every_loan()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddLoans(count: 12, overdue: false);
        await f.SaveAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => f.GenerateAsync(overdueOnly: false));
    }

    [Fact]
    public async Task Overdue_only_combines_with_the_other_requested_filters()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddLoans(count: 10, overdue: false);
        f.AddLoans(count: 2, overdue: true, currency: "EUR");
        f.AddLoans(count: 2, overdue: true);
        await f.SaveAsync();

        // Currency narrows first, then overdue, and only then is the limit checked.
        var rows = await f.GenerateAsync(overdueOnly: true, currency: "EUR");

        Assert.Equal(2, rows.Count);
        Assert.All(rows, row => Assert.Equal("EUR", row.Currency));
        Assert.All(rows, row => Assert.True(row.IsOverdue));
    }

    [Fact]
    public async Task A_completed_loan_with_no_pending_installment_is_not_overdue()
    {
        await using var f = await Fixture.CreateAsync();
        // A past due date that has already been paid must not qualify.
        f.AddLoans(count: 2, overdue: false, paidButPastDue: true);
        f.AddLoans(count: 1, overdue: true);
        await f.SaveAsync();

        var rows = await f.GenerateAsync(overdueOnly: true);

        Assert.Single(rows);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User user, Account account, LoanProduct product)
        {
            Db = db; User = user; Account = account; Product = product;
        }

        public BankingAppDbContext Db { get; }
        private User User { get; }
        private Account Account { get; }
        private LoanProduct Product { get; }

        public async Task<IReadOnlyList<LoanReportRow>> GenerateAsync(
            bool overdueOnly,
            string? currency = null)
        {
            var generator = new CapturingGenerator();
            var job = new ReportJob
            {
                Id = Guid.NewGuid(),
                Type = ReportType.LoanPortfolioReport,
                Status = ReportJobStatus.Queued,
                FilterJson = System.Text.Json.JsonSerializer.Serialize(
                    new LoanPortfolioReportRequest
                    {
                        OverdueOnly = overdueOnly,
                        Currency = currency
                    }),
                RequestedByUserId = Guid.NewGuid(),
                RequestedAtUtc = DateTime.UtcNow
            };
            Db.ReportJobs.Add(job);
            await Db.SaveChangesAsync();

            var options = Options.Create(new ReportGenerationOptions
            {
                MaxRows = MaxRows,
                OutputDirectory = Path.Combine(
                    Path.GetTempPath(), "item15-reports", Guid.NewGuid().ToString("N"))
            });
            var handler = new ReportGenerationHandler(Db, generator, options);
            try
            {
                await handler.HandleAsync(
                    ReportGenerationMessageSerializer.Serialize(
                        new ReportGenerationRequested(job.Id, DateTime.UtcNow)),
                    CancellationToken.None);
            }
            finally
            {
                if (Directory.Exists(options.Value.OutputDirectory))
                    Directory.Delete(options.Value.OutputDirectory, true);
            }
            return generator.Rows;
        }

        public void AddLoans(
            int count,
            bool overdue,
            string currency = "BAM",
            bool paidButPastDue = false)
        {
            var now = DateTime.UtcNow;
            for (var index = 0; index < count; index++)
            {
                var applicationId = Guid.NewGuid();
                var loanId = Guid.NewGuid();
                Db.LoanApplications.Add(new LoanApplication
                {
                    Id = applicationId, UserId = User.Id, LoanProductId = Product.Id,
                    DestinationAccountId = Account.Id, Principal = 1000, Currency = currency,
                    TermMonths = 12, Status = LoanApplicationStatus.Approved,
                    SubmittedAtUtc = now.AddDays(-30), ClientRequestId = Guid.NewGuid()
                });
                Db.Loans.Add(new Loan
                {
                    Id = loanId, LoanApplicationId = applicationId, UserId = User.Id,
                    DestinationAccountId = Account.Id, OriginalPrincipal = 1000,
                    OutstandingPrincipal = 800, Currency = currency, TermMonths = 12,
                    AnnualInterestRate = 5, MonthlyPayment = 90, TotalRepayment = 1080,
                    Status = LoanStatus.Active, StartDateUtc = now.AddMonths(-2),
                    NextPaymentDateUtc = now.AddMonths(1), MaturityDateUtc = now.AddYears(1),
                    CreatedAtUtc = now.AddDays(-index)
                });
                Db.LoanInstallments.Add(new LoanInstallment
                {
                    Id = Guid.NewGuid(), LoanId = loanId, InstallmentNumber = 1,
                    ScheduledAmount = 90,
                    // Overdue = a pending installment already past its due date.
                    DueDateUtc = overdue || paidButPastDue ? now.AddDays(-5) : now.AddDays(20),
                    Status = paidButPastDue
                        ? LoanInstallmentStatus.Paid
                        : LoanInstallmentStatus.Pending
                });
            }
        }

        public Task SaveAsync() => Db.SaveChangesAsync();

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var user = new User
            {
                Id = Guid.NewGuid(), FirstName = "Loan", LastName = "Customer",
                Email = $"{Guid.NewGuid()}@test.local", PhoneNumber = "+38761000000",
                PasswordHash = "hash", Role = AppRoles.Customer,
                Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
            };
            var account = new Account
            {
                Id = Guid.NewGuid(), UserId = user.Id, User = user,
                AccountNumber = "BA-REPORT-CHECKING", AccountTypeId = AccountTypeCodes.CheckingId,
                Currency = "BAM", Balance = 100, Status = AccountStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            var product = new LoanProduct
            {
                Id = Guid.NewGuid(), Name = "Personal", Currency = "BAM",
                MinPrincipal = 100, MaxPrincipal = 10000, AnnualInterestRate = 5,
                MinTermMonths = 6, MaxTermMonths = 24, TermStepMonths = 1, IsActive = true
            };
            db.Users.Add(user);
            db.Accounts.Add(account);
            db.LoanProducts.Add(product);
            await db.SaveChangesAsync();
            return new Fixture(db, user, account, product);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CapturingGenerator : IReportPdfGenerator
    {
        public IReadOnlyList<LoanReportRow> Rows { get; private set; } = [];

        public byte[] Transactions(IReadOnlyList<TransactionReportRow> rows, DateTime generatedAtUtc) =>
            [1, 2, 3];

        public byte[] Loans(IReadOnlyList<LoanReportRow> rows, DateTime generatedAtUtc)
        {
            Rows = rows;
            return [1, 2, 3];
        }
    }
}
