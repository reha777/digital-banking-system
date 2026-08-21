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

public class AdminLoanLifecycleReadTests
{
    [Fact]
    public async Task Active_and_completed_lists_are_filtered_paginated_and_searchable()
    {
        await using var fixture = await Fixture.CreateAsync();
        var active = await fixture.Service.GetLoansAsync(new AdminLoanQueryRequest { Status = LoanStatus.Active, Page = 1, PageSize = 1, Search = "Amira" });
        Assert.Equal(3, active.TotalCount);
        Assert.Single(active.Items);
        Assert.Equal(LoanStatus.Active, active.Items.Single().Status);
        Assert.True(active.Items.Single().RemainingInstallments > 0);
        var completed = await fixture.Service.GetLoansAsync(new AdminLoanQueryRequest { Status = LoanStatus.Completed, Search = "EUR Personal", DateFromUtc = DateTime.UtcNow.AddDays(-2) });
        Assert.Single(completed.Items);
        Assert.Equal(0, completed.Items.Single().OutstandingPrincipal);
        Assert.Equal(0, completed.Items.Single().RemainingInstallments);
        Assert.Null(completed.Items.Single().NextPaymentDateUtc);
    }

    [Fact]
    public async Task Date_filter_uses_start_for_active_and_completed_date_for_completed()
    {
        await using var fixture = await Fixture.CreateAsync();
        var active = await fixture.Service.GetLoansAsync(new AdminLoanQueryRequest { Status = LoanStatus.Active, DateFromUtc = DateTime.UtcNow.AddDays(-3) });
        Assert.Equal(2, active.Items.Count);
        var completed = await fixture.Service.GetLoansAsync(new AdminLoanQueryRequest { Status = LoanStatus.Completed, DateToUtc = DateTime.UtcNow.AddDays(-3) });
        Assert.Empty(completed.Items);
    }

    [Fact]
    public async Task Details_return_customer_lifecycle_schedule_payment_and_progress()
    {
        await using var fixture = await Fixture.CreateAsync();
        var details = await fixture.Service.GetLoanDetailsAsync(fixture.Completed.Id);
        Assert.Equal("Amira Customer", details.CustomerName);
        Assert.Equal("**** 2222", details.DestinationAccount.MaskedAccountNumber);
        Assert.Equal(LoanApplicationStatus.Approved, details.ApplicationStatus);
        Assert.Equal(details.TermMonths, details.PaidInstallments);
        Assert.Equal(0, details.RemainingInstallments);
        Assert.All(details.Installments, item => Assert.Equal(LoanInstallmentStatus.Paid, item.Status));
        var payment = Assert.Single(details.Payments);
        Assert.Equal("**** 2222", payment.SourceAccountNumber);
        Assert.Equal("LOAN-PAY-TEST", payment.TransactionReference);
    }

    [Fact]
    public async Task Summary_separates_financial_values_by_currency()
    {
        await using var fixture = await Fixture.CreateAsync();
        var summary = await fixture.Service.GetLoansOverviewAsync();
        Assert.Equal(3, summary.ActiveLoans);
        Assert.Equal(1, summary.CompletedLoans);
        Assert.Equal(4, summary.TotalApplications);
        Assert.Equal(2, summary.Currencies.Count);
        Assert.Equal(3000, summary.Currencies.Single(value => value.Currency == "BAM").OutstandingPrincipal);
        Assert.Equal(1000, summary.Currencies.Single(value => value.Currency == "EUR").TotalDisbursed);
    }

    [Fact]
    public async Task Non_admin_cannot_use_admin_loan_read_service()
    {
        await using var fixture = await Fixture.CreateAsync(admin: false);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.GetLoansAsync(new AdminLoanQueryRequest { Status = LoanStatus.Active }));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.GetLoanDetailsAsync(fixture.Completed.Id));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.GetLoansOverviewAsync());
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, AdminLoanService service, Loan completed) { Db = db; Service = service; Completed = completed; }
        public BankingAppDbContext Db { get; }
        public AdminLoanService Service { get; }
        public Loan Completed { get; }
        public static async Task<Fixture> CreateAsync(bool admin = true)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var now = DateTime.UtcNow;
            var owner = new User { Id = Guid.NewGuid(), FirstName = "Amira", LastName = "Customer", Email = "amira@example.com", PhoneNumber = "1", PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = now };
            var bam = Product("BAM Personal Loan", "BAM", now); var eur = Product("EUR Personal Loan", "EUR", now);
            var bamAccount = Account(owner, "BA0000001111", "BAM", now); var eurAccount = Account(owner, "BA0000002222", "EUR", now);
            db.AddRange(owner, bam, eur, bamAccount, eurAccount);
            var applications = new List<LoanApplication>(); var loans = new List<Loan>();
            for (var index = 0; index < 3; index++)
            {
                var app = Application(owner, bamAccount, bam, now.AddDays(-index - 1));
                applications.Add(app); loans.Add(Loan(app, owner, bamAccount, LoanStatus.Active, now.AddDays(-index - 1)));
            }
            var completedApp = Application(owner, eurAccount, eur, now.AddDays(-5));
            var completed = Loan(completedApp, owner, eurAccount, LoanStatus.Completed, now.AddDays(-5));
            completed.CompletedAtUtc = now.AddDays(-1); completed.OutstandingPrincipal = 0; completed.TotalPaid = completed.TotalRepayment;
            applications.Add(completedApp); loans.Add(completed);
            db.LoanApplications.AddRange(applications); db.Loans.AddRange(loans);
            foreach (var loan in loans)
            {
                var paid = loan.Status == LoanStatus.Completed;
                db.LoanInstallments.Add(new LoanInstallment { Id = Guid.NewGuid(), LoanId = loan.Id, InstallmentNumber = 1, DueDateUtc = loan.StartDateUtc.AddMonths(1), ScheduledAmount = 1050, PrincipalAmount = 1000, InterestAmount = 50, RemainingPrincipalAfter = 0, Status = paid ? LoanInstallmentStatus.Paid : LoanInstallmentStatus.Pending, PaidAtUtc = paid ? now.AddDays(-1) : null });
                loan.TermMonths = 1;
            }
            await db.SaveChangesAsync(); db.ChangeTracker.Clear();
            var installment = await db.LoanInstallments.SingleAsync(value => value.LoanId == completed.Id);
            var transaction = new Transaction { Id = Guid.NewGuid(), AccountId = eurAccount.Id, SourceAccountId = eurAccount.Id, ReferenceNumber = "LOAN-PAY-TEST", Amount = -1050, Type = TransactionType.LoanRepayment, Description = "Loan repayment", Status = TransactionStatus.Completed, CreatedAtUtc = now.AddDays(-1) };
            var payment = new LoanPayment { Id = Guid.NewGuid(), LoanId = completed.Id, LoanInstallmentId = installment.Id, SourceAccountId = eurAccount.Id, TransactionId = transaction.Id, Amount = 1050, PrincipalAmount = 1000, InterestAmount = 50, PaidAtUtc = now.AddDays(-1), Status = LoanPaymentStatus.Completed, ClientRequestId = Guid.NewGuid() };
            installment.LoanPaymentId = payment.Id; db.AddRange(transaction, payment); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
            return new Fixture(db, new AdminLoanService(db, new CurrentUser(admin), new LoanCalculationService()), completed);
        }
        private static LoanProduct Product(string name, string currency, DateTime now) => new() { Id = Guid.NewGuid(), Name = name, Description = "Test", Currency = currency, MinPrincipal = 1, MaxPrincipal = 10000, AnnualInterestRate = 5, MinTermMonths = 1, MaxTermMonths = 12, TermStepMonths = 1, IsActive = true, CreatedAtUtc = now, UpdatedAtUtc = now };
        private static Account Account(User user, string number, string currency, DateTime now) => new() { Id = Guid.NewGuid(), UserId = user.Id, AccountNumber = number, Currency = currency, Balance = 5000, AccountType = AccountType.Checking, CreatedAtUtc = now };
        private static LoanApplication Application(User user, Account account, LoanProduct product, DateTime submitted) => new() { Id = Guid.NewGuid(), UserId = user.Id, DestinationAccountId = account.Id, LoanProductId = product.Id, Principal = 1000, Currency = product.Currency, AnnualInterestRateSnapshot = 5, TermMonths = 1, EstimatedMonthlyPayment = 1050, EstimatedTotalInterest = 50, EstimatedTotalRepayment = 1050, Status = LoanApplicationStatus.Approved, SubmittedAtUtc = submitted, ReviewedAtUtc = submitted.AddDays(1), ClientRequestId = Guid.NewGuid(), AdminNote = "Approved" };
        private static Loan Loan(LoanApplication app, User user, Account account, LoanStatus status, DateTime start) => new() { Id = Guid.NewGuid(), LoanApplicationId = app.Id, UserId = user.Id, DestinationAccountId = account.Id, OriginalPrincipal = 1000, OutstandingPrincipal = 1000, Currency = app.Currency, AnnualInterestRate = 5, TermMonths = 1, MonthlyPayment = 1050, TotalRepayment = 1050, TotalPaid = 0, StartDateUtc = start, NextPaymentDateUtc = start.AddMonths(1), MaturityDateUtc = start.AddMonths(1), Status = status, CreatedAtUtc = start };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(bool admin) : ICurrentUserService { public Guid UserId => Guid.NewGuid(); public bool IsAdmin => admin; }
}
