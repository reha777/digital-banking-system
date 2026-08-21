using System.Reflection;
using BankingApp.Api.Controllers;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Loans;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AdminLoanReadTests
{
    [Fact]
    public void Admin_controller_is_restricted_to_admin_role()
    {
        var attribute = typeof(AdminLoansController).GetCustomAttribute<AuthorizeAttribute>();
        Assert.NotNull(attribute);
        Assert.Equal(AppRoles.Admin, attribute.Roles);
    }

    [Fact]
    public async Task List_is_paginated_and_sorted_newest_first()
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetApplicationsAsync(new AdminLoanApplicationQueryRequest { Page = 1, PageSize = 2 });
        Assert.Equal(4, result.TotalCount);
        Assert.Equal(2, result.Items.Count);
        Assert.True(result.Items.First().SubmittedAtUtc >= result.Items.Last().SubmittedAtUtc);
    }

    [Theory]
    [InlineData("Amira", 2)]
    [InlineData("amira@example.com", 2)]
    [InlineData("EUR Personal", 2)]
    public async Task Search_matches_customer_name_email_and_product(string search, int expected)
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetApplicationsAsync(new AdminLoanApplicationQueryRequest { Search = search });
        Assert.Equal(expected, result.TotalCount);
    }

    [Fact]
    public async Task Status_and_date_filters_are_applied()
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetApplicationsAsync(new AdminLoanApplicationQueryRequest
        {
            Status = LoanApplicationStatus.Rejected,
            DateFromUtc = DateTime.UtcNow.AddDays(-4)
        });
        Assert.Single(result.Items);
        Assert.Equal(LoanApplicationStatus.Rejected, result.Items.Single().Status);
    }

    [Fact]
    public async Task Details_include_customer_account_and_application_snapshot()
    {
        await using var fixture = await Fixture.CreateAsync();
        var details = await fixture.Service.GetApplicationDetailsAsync(fixture.Pending.Id);
        Assert.Equal(fixture.Owner.Id, details.Customer.Id);
        Assert.Equal("amira@example.com", details.Customer.Email);
        Assert.Equal("**** 1234", details.DestinationAccount.MaskedAccountNumber);
        Assert.Equal(6.25m, details.Financials.AnnualInterestRate);
        Assert.Equal(171.20m, details.Financials.EstimatedMonthlyPayment);
        Assert.Equal(1027.20m, details.Financials.EstimatedTotalRepayment);
    }

    [Fact]
    public async Task Unknown_details_id_throws_not_found()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Service.GetApplicationDetailsAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task Summary_counts_use_the_same_filters()
    {
        await using var fixture = await Fixture.CreateAsync();
        var all = await fixture.Service.GetSummaryAsync(new AdminLoanApplicationQueryRequest());
        Assert.Equal(4, all.TotalApplications);
        Assert.Equal(2, all.PendingApplications);
        Assert.Equal(1, all.ApprovedApplications);
        Assert.Equal(1, all.RejectedApplications);
        var amira = await fixture.Service.GetSummaryAsync(new AdminLoanApplicationQueryRequest { Search = "Amira" });
        Assert.Equal(2, amira.TotalApplications);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, LoanApplication pending)
        {
            Db = db; Owner = owner; Pending = pending;
            Service = new AdminLoanService(db, new CurrentUser(Guid.NewGuid()), new LoanCalculationService());
        }
        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public LoanApplication Pending { get; }
        public AdminLoanService Service { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Amira", "Hadžić", "amira@example.com");
            var second = User("Marko", "Marić", "marko@example.com");
            var bam = Product("BAM Personal Loan", "BAM");
            var eur = Product("EUR Personal Loan", "EUR");
            var ownerAccount = Account(owner, "BA0000001234", "BAM");
            var secondAccount = Account(second, "BA0000009876", "EUR");
            db.AddRange(owner, second, bam, eur, ownerAccount, secondAccount);
            var pending = Application(owner, ownerAccount, bam, LoanApplicationStatus.Pending, 1);
            db.LoanApplications.AddRange(
                pending,
                Application(owner, ownerAccount, bam, LoanApplicationStatus.Approved, 8),
                Application(second, secondAccount, eur, LoanApplicationStatus.Rejected, 2),
                Application(second, secondAccount, eur, LoanApplicationStatus.Pending, 6));
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();
            return new Fixture(db, owner, pending);
        }

        private static User User(string first, string last, string email) => new()
        {
            Id = Guid.NewGuid(), FirstName = first, LastName = last, Email = email, PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };
        private static LoanProduct Product(string name, string currency) => new()
        {
            Id = Guid.NewGuid(), Name = name, Description = "Test", Currency = currency, MinPrincipal = 500,
            MaxPrincipal = 25000, AnnualInterestRate = 6.25m, MinTermMonths = 6, MaxTermMonths = 60,
            TermStepMonths = 6, IsActive = true, CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow
        };
        private static Account Account(User user, string number, string currency) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, AccountNumber = number, AccountType = AccountType.Checking,
            Balance = 2500, Currency = currency, CreatedAtUtc = DateTime.UtcNow
        };
        private static LoanApplication Application(User user, Account account, LoanProduct product, LoanApplicationStatus status, int daysAgo) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, LoanProductId = product.Id, DestinationAccountId = account.Id,
            Principal = 1000, Currency = product.Currency, AnnualInterestRateSnapshot = 6.25m, TermMonths = 6,
            EstimatedMonthlyPayment = 171.20m, EstimatedTotalInterest = 27.20m, EstimatedTotalRepayment = 1027.20m,
            Status = status, SubmittedAtUtc = DateTime.UtcNow.AddDays(-daysAgo), ReviewedAtUtc = status == LoanApplicationStatus.Pending ? null : DateTime.UtcNow.AddDays(-daysAgo + 1),
            AdminNote = status == LoanApplicationStatus.Rejected ? "Income verification failed." : null, ClientRequestId = Guid.NewGuid()
        };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : BankingApp.Application.Interfaces.ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => true;
    }
}
