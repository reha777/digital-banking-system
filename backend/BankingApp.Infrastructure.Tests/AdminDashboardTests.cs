using BankingApp.Api.Controllers;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AdminDashboardTests
{
    [Fact]
    public void Endpoint_is_admin_only()
    {
        var authorize = Assert.Single(typeof(AdminDashboardController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, authorize.Roles);
    }

    [Fact]
    public async Task Aggregate_is_currency_correct_ordered_limited_and_operational()
    {
        await using var db = new BankingAppDbContext(
            new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var active = User("Active", CustomerStatus.Active);
        var inactive = User("Inactive", CustomerStatus.Inactive);
        var deleted = User("Deleted", CustomerStatus.Active); deleted.IsDeleted = true;
        var usd = Account(active, "USD-1", "USD");
        var eur = Account(inactive, "EUR-1", "EUR");
        var product = new LoanProduct
        {
            Id = Guid.NewGuid(), Name = "Personal", Currency = "USD",
            AnnualInterestRate = 5, MinPrincipal = 100, MaxPrincipal = 10000,
            MinTermMonths = 6, MaxTermMonths = 24, TermStepMonths = 6,
            IsActive = true, CreatedAtUtc = DateTime.UtcNow
        };
        var pendingApplication = Application(active, usd, product, LoanApplicationStatus.Pending);
        var approvedApplication = Application(active, usd, product, LoanApplicationStatus.Approved);
        var loan = Loan(active, usd, approvedApplication);
        loan.Installments.Add(new LoanInstallment
        {
            Id = Guid.NewGuid(), LoanId = loan.Id, Loan = loan, InstallmentNumber = 1,
            DueDateUtc = DateTime.UtcNow.AddDays(-2), ScheduledAmount = 90,
            PrincipalAmount = 80, InterestAmount = 10, RemainingPrincipalAfter = 720,
            Status = LoanInstallmentStatus.Pending
        });
        db.Users.AddRange(active, inactive, deleted);
        db.Accounts.AddRange(usd, eur); db.LoanProducts.Add(product);
        db.LoanApplications.AddRange(pendingApplication, approvedApplication); db.Loans.Add(loan);
        db.CardRequests.Add(new CardRequest
        {
            Id = Guid.NewGuid(), UserId = active.Id, User = active,
            CardholderName = "Active User", Currency = "USD", DocumentNumber = "D",
            DeliveryAddress = "Address", Status = CardRequestStatus.Pending,
            CreatedAtUtc = DateTime.UtcNow
        });
        for (var index = 0; index < 6; index++)
        {
            db.Transactions.Add(new Transaction
            {
                Id = Guid.NewGuid(), AccountId = index == 0 ? eur.Id : usd.Id,
                Account = index == 0 ? eur : usd, ReferenceNumber = $"TX-{index}",
                Amount = index == 0 ? 25 : -10, Type = index == 1
                    ? TransactionType.InternalTransfer : TransactionType.Transfer,
                Description = "Test", Status = index == 2
                    ? TransactionStatus.Failed : TransactionStatus.Completed,
                IsHighRiskReview = false, CreatedAtUtc = DateTime.UtcNow.AddMinutes(-index)
            });
        }
        db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = usd.Id, Account = usd,
            ReferenceNumber = "REVIEW", Amount = 50, Type = TransactionType.Transfer,
            Description = "Review", Status = TransactionStatus.Pending,
            IsHighRiskReview = true, CreatedAtUtc = DateTime.UtcNow.AddHours(-1)
        });
        db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = usd.Id, Account = usd,
            ReferenceNumber = "DOCS", Amount = 50, Type = TransactionType.Transfer,
            Description = "Documents", Status = TransactionStatus.DocumentsRequested,
            CreatedAtUtc = DateTime.UtcNow.AddHours(-2)
        });
        await db.SaveChangesAsync();

        var result = await new AdminDashboardService(db).GetAsync(7);

        Assert.Equal(2, result.TotalCustomers);
        Assert.Equal(1, result.ActiveCustomers);
        Assert.Equal(8, result.TotalTransactions);
        Assert.Equal(5, result.CompletedTransactions);
        Assert.Equal(1, result.FailedTransactions);
        Assert.Equal(1, result.PendingTransactionReviews);
        Assert.Equal(1, result.DocumentsRequested);
        Assert.Equal(1, result.PendingCardRequests);
        Assert.Equal(1, result.PendingLoanApplications);
        Assert.Equal(1, result.ActiveLoans);
        Assert.Equal(1, result.LoansWithOverduePayments);
        Assert.Equal(25, result.TransferredByCurrency.Single(x => x.Currency == "EUR").Amount);
        Assert.Equal(40, result.TransferredByCurrency.Single(x => x.Currency == "USD").Amount);
        Assert.Equal(5, result.RecentTransactions.Count);
        Assert.Equal("TX-0", result.RecentTransactions.First().ReferenceNumber);
        Assert.Contains(result.RecentTransactions, x => x.Type == TransactionType.InternalTransfer);
        Assert.Equal("EUR", result.RecentTransactions.First().Currency);
        Assert.Equal(7, result.PeriodDays);
        Assert.Equal(7, result.TransactionActivity.Count);
        Assert.Equal(8, result.TransactionActivity.Last().TransactionCount);
        Assert.Equal(0, result.TransactionActivity.First().TransactionCount);
        Assert.True(result.TransactionActivity
            .Zip(result.TransactionActivity.Skip(1), (left, right) => left.DateUtc < right.DateUtc)
            .All(value => value));
    }

    [Fact]
    public async Task Activity_supports_thirty_days_and_rejects_invalid_period()
    {
        await using var db = new BankingAppDbContext(
            new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

        var service = new AdminDashboardService(db);
        var result = await service.GetAsync(30);

        Assert.Equal(30, result.PeriodDays);
        Assert.Equal(30, result.TransactionActivity.Count);
        Assert.All(result.TransactionActivity, point => Assert.Equal(0, point.TransactionCount));
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => service.GetAsync(14));
    }

    private static User User(string name, CustomerStatus status) => new()
    {
        Id = Guid.NewGuid(), FirstName = name, LastName = "User",
        Email = $"{Guid.NewGuid()}@test.com", PhoneNumber = "+38761000000",
        PasswordHash = "hash", Role = AppRoles.Customer, Status = status,
        CreatedAtUtc = DateTime.UtcNow
    };
    private static Account Account(User user, string number, string currency) => new()
    {
        Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = number,
        Currency = currency, AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow
    };
    private static LoanApplication Application(User user, Account account, LoanProduct product, LoanApplicationStatus status) => new()
    {
        Id = Guid.NewGuid(), UserId = user.Id, User = user, DestinationAccountId = account.Id,
        DestinationAccount = account, LoanProductId = product.Id, LoanProduct = product,
        Principal = 1000, Currency = "USD", AnnualInterestRateSnapshot = 5,
        TermMonths = 12, EstimatedMonthlyPayment = 90, EstimatedTotalInterest = 80,
        EstimatedTotalRepayment = 1080, Status = status, SubmittedAtUtc = DateTime.UtcNow,
        ClientRequestId = Guid.NewGuid()
    };
    private static Loan Loan(User user, Account account, LoanApplication application) => new()
    {
        Id = Guid.NewGuid(), LoanApplicationId = application.Id, LoanApplication = application,
        UserId = user.Id, User = user, DestinationAccountId = account.Id, DestinationAccount = account,
        OriginalPrincipal = 1000, OutstandingPrincipal = 800, Currency = "USD",
        AnnualInterestRate = 5, TermMonths = 12, MonthlyPayment = 90,
        TotalRepayment = 1080, StartDateUtc = DateTime.UtcNow.AddMonths(-2),
        NextPaymentDateUtc = DateTime.UtcNow.AddMonths(1), MaturityDateUtc = DateTime.UtcNow.AddMonths(10),
        Status = LoanStatus.Active, CreatedAtUtc = DateTime.UtcNow.AddMonths(-2)
    };
}
