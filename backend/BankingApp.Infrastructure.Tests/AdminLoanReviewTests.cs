using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AdminLoanReviewTests
{
    [Fact]
    public async Task Reject_requires_reason_and_changes_only_review_metadata()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.RejectApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "  " }));
        var beforeBalance = fixture.Account.Balance;
        var result = await fixture.Service.RejectApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "  Income verification failed.  " });
        Assert.Equal(LoanApplicationStatus.Rejected, result.Status);
        Assert.Equal("Income verification failed.", result.AdminNote);
        var stored = await fixture.Db.LoanApplications.SingleAsync();
        Assert.Equal(fixture.AdminId, stored.ReviewedByUserId);
        Assert.NotNull(stored.ReviewedAtUtc);
        Assert.Equal(beforeBalance, (await fixture.Db.Accounts.SingleAsync()).Balance);
        Assert.Empty(fixture.Db.Loans);
        Assert.Empty(fixture.Db.LoanInstallments);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Fact]
    public async Task Duplicate_reject_and_approve_after_reject_are_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.RejectApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "Reason" });
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.RejectApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "Again" }));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest()));
    }

    [Fact]
    public async Task Approve_atomically_creates_loan_schedule_disbursement_and_review()
    {
        await using var fixture = await Fixture.CreateAsync();
        var before = fixture.Account.Balance;
        var result = await fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "Approved after review" });
        Assert.Equal(LoanApplicationStatus.Approved, result.Status);
        var loan = Assert.Single(await fixture.Db.Loans.AsNoTracking().ToListAsync());
        var transaction = Assert.Single(await fixture.Db.Transactions.AsNoTracking().ToListAsync());
        var installments = await fixture.Db.LoanInstallments.AsNoTracking().OrderBy(value => value.InstallmentNumber).ToListAsync();
        var application = await fixture.Db.LoanApplications.AsNoTracking().SingleAsync();
        Assert.Equal(before + fixture.Application.Principal, (await fixture.Db.Accounts.AsNoTracking().SingleAsync()).Balance);
        Assert.Equal(fixture.Application.Id, loan.LoanApplicationId);
        Assert.Equal(fixture.Application.Principal, loan.OriginalPrincipal);
        Assert.Equal(fixture.Application.Principal, loan.OutstandingPrincipal);
        Assert.Equal(0, loan.TotalPaid);
        Assert.Equal(LoanStatus.Active, loan.Status);
        Assert.Equal(TransactionType.LoanDisbursement, transaction.Type);
        Assert.Equal(TransactionStatus.Completed, transaction.Status);
        Assert.Equal(fixture.Application.Principal, transaction.Amount);
        Assert.Equal(fixture.Account.Id, transaction.AccountId);
        Assert.Equal(transaction.Id, loan.DisbursementTransactionId);
        Assert.StartsWith("LOAN-", transaction.ReferenceNumber);
        Assert.Equal(fixture.Application.TermMonths, installments.Count);
        Assert.Equal(loan.StartDateUtc.Date.AddMonths(1), installments.First().DueDateUtc);
        Assert.Equal(0, installments.Last().RemainingPrincipalAfter);
        Assert.Equal(installments.First().DueDateUtc, loan.NextPaymentDateUtc);
        Assert.Equal(installments.Last().DueDateUtc, loan.MaturityDateUtc);
        Assert.All(installments, value => Assert.Equal(LoanInstallmentStatus.Pending, value.Status));
        Assert.Equal(fixture.AdminId, application.ReviewedByUserId);
        Assert.NotNull(application.ReviewedAtUtc);
    }

    [Fact]
    public async Task Approve_uses_application_snapshot_not_changed_product_rate()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Product.AnnualInterestRate = 99m;
        await fixture.Db.SaveChangesAsync();
        fixture.Db.ChangeTracker.Clear();
        await fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest());
        var loan = await fixture.Db.Loans.SingleAsync();
        Assert.Equal(Fixture.SnapshotRate, loan.AnnualInterestRate);
        Assert.Equal(fixture.Application.EstimatedMonthlyPayment, loan.MonthlyPayment);
    }

    [Fact]
    public async Task Duplicate_approve_does_not_credit_twice_or_duplicate_records()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest());
        var approvedBalance = (await fixture.Db.Accounts.AsNoTracking().SingleAsync()).Balance;
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest()));
        Assert.Equal(approvedBalance, (await fixture.Db.Accounts.AsNoTracking().SingleAsync()).Balance);
        Assert.Equal(1, await fixture.Db.Loans.CountAsync());
        Assert.Equal(1, await fixture.Db.Transactions.CountAsync());
        Assert.Equal(fixture.Application.TermMonths, await fixture.Db.LoanInstallments.CountAsync());
    }

    [Fact]
    public async Task Active_loan_blocks_approve_without_any_disbursement()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.AddExistingActiveLoanAsync();
        var balance = fixture.Account.Balance;
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest()));
        Assert.Equal(balance, (await fixture.Db.Accounts.AsNoTracking().SingleAsync()).Balance);
        Assert.Equal(LoanApplicationStatus.Pending, (await fixture.Db.LoanApplications.AsNoTracking().SingleAsync()).Status);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Destination_ownership_and_currency_are_revalidated(bool foreignOwner, bool wrongCurrency)
    {
        await using var fixture = await Fixture.CreateAsync();
        var account = await fixture.Db.Accounts.SingleAsync();
        if (foreignOwner) account.UserId = Guid.NewGuid();
        if (wrongCurrency) account.Currency = "EUR";
        await fixture.Db.SaveChangesAsync();
        fixture.Db.ChangeTracker.Clear();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest()));
        Assert.Empty(fixture.Db.Loans);
        Assert.Empty(fixture.Db.Transactions);
    }

    [Fact]
    public async Task Non_admin_cannot_review_application()
    {
        await using var fixture = await Fixture.CreateAsync(admin: false);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest()));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.RejectApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest { AdminNote = "Reason" }));
    }

    [Fact]
    public async Task Loan_disbursement_is_visible_in_history_and_counted_as_statistics_income()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.ApproveApplicationAsync(fixture.Application.Id, new AdminLoanReviewRequest());
        fixture.Db.ChangeTracker.Clear();
        var transactions = new TransactionService(
            fixture.Db,
            new CustomerUser(fixture.Owner.Id),
            new DemoCurrencyConversionService());
        var history = await transactions.GetAsync(new TransactionQueryRequest { Page = 1, PageSize = 20 });
        var disbursement = Assert.Single(history.Items);
        Assert.Equal(TransactionType.LoanDisbursement, disbursement.Type);
        Assert.Equal(fixture.Application.Principal, disbursement.Amount);
        var start = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1);
        var statistics = await transactions.GetStatisticsAsync(new TransactionStatisticsQuery
        {
            From = start.AddMonths(-1),
            To = start.AddMonths(1)
        });
        var month = Assert.Single(statistics.CurrencySeries).Months.Single(value => value.Month == DateTime.UtcNow.Month);
        Assert.Equal(fixture.Application.Principal, month.Income);
        Assert.Equal(0, month.Spending);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, AdminLoanService service, Guid adminId, User owner, Account account, LoanProduct product, LoanApplication application)
        { Db = db; Service = service; AdminId = adminId; Owner = owner; Account = account; Product = product; Application = application; }
        public const decimal SnapshotRate = 6.5m;
        public BankingAppDbContext Db { get; }
        public AdminLoanService Service { get; }
        public Guid AdminId { get; }
        public User Owner { get; }
        public Account Account { get; }
        public LoanProduct Product { get; }
        public LoanApplication Application { get; }

        public static async Task<Fixture> CreateAsync(bool admin = true)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var calculation = new LoanCalculationService();
            var owner = new User { Id = Guid.NewGuid(), FirstName = "Loan", LastName = "Customer", Email = "loan@example.com", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            var product = new LoanProduct { Id = Guid.NewGuid(), Name = "BAM Personal Loan", Description = "Test", Currency = "BAM", MinPrincipal = 500, MaxPrincipal = 25000, AnnualInterestRate = SnapshotRate, MinTermMonths = 6, MaxTermMonths = 60, TermStepMonths = 6, IsActive = true, CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow };
            var account = new Account { Id = Guid.NewGuid(), UserId = owner.Id, AccountNumber = "BA0000001234", AccountType = AccountType.Checking, Balance = 100, Currency = "BAM", CreatedAtUtc = DateTime.UtcNow };
            var quote = calculation.Calculate(1000, SnapshotRate, 6, DateTime.UtcNow.AddDays(-1));
            var application = new LoanApplication { Id = Guid.NewGuid(), UserId = owner.Id, LoanProductId = product.Id, DestinationAccountId = account.Id, Principal = quote.Principal, Currency = "BAM", AnnualInterestRateSnapshot = SnapshotRate, TermMonths = 6, EstimatedMonthlyPayment = quote.MonthlyPayment, EstimatedTotalInterest = quote.TotalInterest, EstimatedTotalRepayment = quote.TotalRepayment, Status = LoanApplicationStatus.Pending, SubmittedAtUtc = DateTime.UtcNow.AddDays(-1), ClientRequestId = Guid.NewGuid() };
            db.AddRange(owner, product, account, application);
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();
            var adminId = Guid.NewGuid();
            return new Fixture(db, new AdminLoanService(db, new CurrentUser(adminId, admin), calculation), adminId, owner, account, product, application);
        }

        public async Task AddExistingActiveLoanAsync()
        {
            Db.Loans.Add(new Loan { Id = Guid.NewGuid(), LoanApplicationId = Guid.NewGuid(), UserId = Owner.Id, DestinationAccountId = Account.Id, OriginalPrincipal = 500, OutstandingPrincipal = 500, Currency = "BAM", AnnualInterestRate = 5, TermMonths = 6, MonthlyPayment = 90, TotalRepayment = 540, TotalPaid = 0, StartDateUtc = DateTime.UtcNow, NextPaymentDateUtc = DateTime.UtcNow.AddMonths(1), MaturityDateUtc = DateTime.UtcNow.AddMonths(6), Status = LoanStatus.Active, CreatedAtUtc = DateTime.UtcNow });
            await Db.SaveChangesAsync();
            Db.ChangeTracker.Clear();
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => admin;
    }

    private sealed class CustomerUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
