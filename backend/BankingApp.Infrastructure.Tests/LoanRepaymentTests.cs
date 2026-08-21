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

public class LoanRepaymentTests
{
    [Fact]
    public async Task Current_details_and_quote_are_owned_and_use_next_pending_installment()
    {
        await using var fixture = await Fixture.CreateAsync();
        var current = await fixture.Service.GetCurrentLoanAsync();
        Assert.NotNull(current);
        Assert.Equal(fixture.Loan.Id, current!.LoanId);
        Assert.Equal(fixture.Loan.TermMonths, current.RemainingInstallments);
        var details = await fixture.Service.GetLoanDetailsAsync(fixture.Loan.Id);
        Assert.Equal(fixture.Loan.TermMonths, details.Installments.Count);
        Assert.Empty(details.Payments);
        var quote = await fixture.Service.GetPaymentQuoteAsync(fixture.Loan.Id);
        Assert.Equal(1, quote.InstallmentNumber);
        Assert.Equal(details.Installments.First().ScheduledAmount, quote.Amount);
        Assert.Equal(fixture.Loan.OutstandingPrincipal - quote.PrincipalAmount, quote.OutstandingAfter);

        var foreignService = new LoanService(fixture.Db, new CurrentUser(Guid.NewGuid()), new LoanCalculationService());
        await Assert.ThrowsAsync<NotFoundException>(() => foreignService.GetLoanDetailsAsync(fixture.Loan.Id));
    }

    [Fact]
    public async Task Repayment_debits_total_marks_installment_and_updates_loan_and_history()
    {
        await using var fixture = await Fixture.CreateAsync();
        var before = fixture.Source.Balance;
        var quote = await fixture.Service.GetPaymentQuoteAsync(fixture.Loan.Id);
        var result = await fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.Source.Id, ClientRequestId = Guid.NewGuid() });
        fixture.Db.ChangeTracker.Clear();

        var loan = await fixture.Db.Loans.SingleAsync();
        var installment = await fixture.Db.LoanInstallments.OrderBy(value => value.InstallmentNumber).FirstAsync();
        var payment = await fixture.Db.LoanPayments.Include(value => value.Transaction).SingleAsync();
        Assert.Equal(before - quote.Amount, (await fixture.Db.Accounts.SingleAsync(value => value.Id == fixture.Source.Id)).Balance);
        Assert.Equal(LoanInstallmentStatus.Paid, installment.Status);
        Assert.Equal(payment.Id, installment.LoanPaymentId);
        Assert.Equal(quote.OutstandingAfter, loan.OutstandingPrincipal);
        Assert.Equal(quote.Amount, loan.TotalPaid);
        Assert.Equal(quote.Amount, payment.Amount);
        Assert.Equal(quote.PrincipalAmount, payment.PrincipalAmount);
        Assert.Equal(quote.InterestAmount, payment.InterestAmount);
        Assert.Equal(TransactionType.LoanRepayment, payment.Transaction.Type);
        Assert.Equal(-quote.Amount, payment.Transaction.Amount);
        Assert.Equal(2, result.InstallmentNumber + 1);
        Assert.Equal((await fixture.Db.LoanInstallments.SingleAsync(value => value.InstallmentNumber == 2)).DueDateUtc, loan.NextPaymentDateUtc);
        var details = await fixture.Service.GetLoanDetailsAsync(fixture.Loan.Id);
        Assert.Single(details.Payments);
        Assert.Equal(payment.Transaction.ReferenceNumber, details.Payments.Single().TransactionReference);
    }

    [Fact]
    public async Task Same_client_request_is_idempotent_and_conflicting_source_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var requestId = Guid.NewGuid();
        var before = fixture.Source.Balance;
        var first = await fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.Source.Id, ClientRequestId = requestId });
        fixture.Db.ChangeTracker.Clear();
        var second = await fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.Source.Id, ClientRequestId = requestId });
        Assert.Equal(first.PaymentId, second.PaymentId);
        Assert.Equal(1, await fixture.Db.LoanPayments.CountAsync());
        Assert.Equal(before - first.Amount, (await fixture.Db.Accounts.SingleAsync(value => value.Id == fixture.Source.Id)).Balance);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.OtherSource.Id, ClientRequestId = requestId }));
    }

    [Theory]
    [InlineData("EUR", 10000, false)]
    [InlineData("BAM", 0, false)]
    [InlineData("BAM", 10000, true)]
    public async Task Invalid_source_currency_balance_or_owner_is_rejected(string currency, decimal balance, bool foreign)
    {
        await using var fixture = await Fixture.CreateAsync();
        var source = await fixture.Db.Accounts.SingleAsync(value => value.Id == fixture.OtherSource.Id);
        source.Currency = currency;
        source.Balance = balance;
        if (foreign) source.UserId = Guid.NewGuid();
        await fixture.Db.SaveChangesAsync();
        fixture.Db.ChangeTracker.Clear();
        await Assert.ThrowsAnyAsync<Exception>(() => fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.OtherSource.Id, ClientRequestId = Guid.NewGuid() }));
        Assert.Empty(fixture.Db.LoanPayments);
    }

    [Fact]
    public async Task Final_payment_completes_loan_exactly_and_repayment_is_statistics_spending()
    {
        await using var fixture = await Fixture.CreateAsync(termMonths: 1);
        var result = await fixture.Service.PayInstallmentAsync(fixture.Loan.Id,
            new LoanPaymentRequest { SourceAccountId = fixture.Source.Id, ClientRequestId = Guid.NewGuid() });
        fixture.Db.ChangeTracker.Clear();
        var loan = await fixture.Db.Loans.SingleAsync();
        Assert.Equal(LoanStatus.Completed, loan.Status);
        Assert.Equal(0, loan.OutstandingPrincipal);
        Assert.Equal(loan.TotalRepayment, loan.TotalPaid);
        Assert.NotNull(loan.CompletedAtUtc);
        Assert.Null(result.NextPaymentDateUtc);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.GetPaymentQuoteAsync(loan.Id));

        var statistics = new TransactionService(fixture.Db, new CurrentUser(fixture.Owner.Id), new DemoCurrencyConversionService());
        var start = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1);
        var response = await statistics.GetStatisticsAsync(new TransactionStatisticsQuery { From = start, To = start.AddMonths(1) });
        Assert.Equal(result.Amount, Assert.Single(response.CurrencySeries).Months.Single().Spending);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, LoanService service, User owner, Account source, Account otherSource, Loan loan)
        { Db = db; Service = service; Owner = owner; Source = source; OtherSource = otherSource; Loan = loan; }
        public BankingAppDbContext Db { get; }
        public LoanService Service { get; }
        public User Owner { get; }
        public Account Source { get; }
        public Account OtherSource { get; }
        public Loan Loan { get; }

        public static async Task<Fixture> CreateAsync(int termMonths = 6)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var now = DateTime.UtcNow;
            var owner = new User { Id = Guid.NewGuid(), FirstName = "Loan", LastName = "Owner", Email = "owner@test", PhoneNumber = "1", PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = now };
            var product = new LoanProduct { Id = Guid.NewGuid(), Name = "Personal Loan", Description = "Test", Currency = "BAM", MinPrincipal = 1, MaxPrincipal = 100000, AnnualInterestRate = 6.5m, MinTermMonths = 1, MaxTermMonths = 60, TermStepMonths = 1, IsActive = true, CreatedAtUtc = now, UpdatedAtUtc = now };
            var destination = new Account { Id = Guid.NewGuid(), UserId = owner.Id, AccountNumber = "BA0000001000", Currency = "BAM", Balance = 0, AccountType = AccountType.Checking, CreatedAtUtc = now };
            var source = new Account { Id = Guid.NewGuid(), UserId = owner.Id, AccountNumber = "BA0000002000", Currency = "BAM", Balance = 10000, AccountType = AccountType.Savings, CreatedAtUtc = now };
            var other = new Account { Id = Guid.NewGuid(), UserId = owner.Id, AccountNumber = "BA0000003000", Currency = "BAM", Balance = 10000, AccountType = AccountType.Checking, CreatedAtUtc = now };
            var calculation = new LoanCalculationService().Calculate(1000, product.AnnualInterestRate, termMonths, now);
            var application = new LoanApplication { Id = Guid.NewGuid(), UserId = owner.Id, LoanProductId = product.Id, DestinationAccountId = destination.Id, Principal = 1000, Currency = "BAM", AnnualInterestRateSnapshot = product.AnnualInterestRate, TermMonths = termMonths, EstimatedMonthlyPayment = calculation.MonthlyPayment, EstimatedTotalInterest = calculation.TotalInterest, EstimatedTotalRepayment = calculation.TotalRepayment, Status = LoanApplicationStatus.Approved, SubmittedAtUtc = now, ReviewedAtUtc = now, ClientRequestId = Guid.NewGuid() };
            var loan = new Loan { Id = Guid.NewGuid(), LoanApplicationId = application.Id, UserId = owner.Id, DestinationAccountId = destination.Id, OriginalPrincipal = 1000, OutstandingPrincipal = 1000, Currency = "BAM", AnnualInterestRate = product.AnnualInterestRate, TermMonths = termMonths, MonthlyPayment = calculation.MonthlyPayment, TotalRepayment = calculation.TotalRepayment, TotalPaid = 0, StartDateUtc = now, NextPaymentDateUtc = calculation.Schedule.First().DueDate, MaturityDateUtc = calculation.Schedule.Last().DueDate, Status = LoanStatus.Active, CreatedAtUtc = now };
            db.AddRange(owner, product, destination, source, other, application, loan);
            db.LoanInstallments.AddRange(calculation.Schedule.Select(value => new LoanInstallment { Id = Guid.NewGuid(), LoanId = loan.Id, InstallmentNumber = value.InstallmentNumber, DueDateUtc = value.DueDate, ScheduledAmount = value.ScheduledAmount, PrincipalAmount = value.PrincipalAmount, InterestAmount = value.InterestAmount, RemainingPrincipalAfter = value.RemainingPrincipalAfter, Status = LoanInstallmentStatus.Pending }));
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();
            return new Fixture(db, new LoanService(db, new CurrentUser(owner.Id), new LoanCalculationService()), owner, source, other, loan);
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
