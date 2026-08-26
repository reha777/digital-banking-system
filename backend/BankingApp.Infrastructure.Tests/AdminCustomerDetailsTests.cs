using BankingApp.Api.Controllers;
using BankingApp.Application.Cards;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Customers;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class AdminCustomerDetailsTests
{
    [Fact]
    public void Customer_details_controller_is_admin_only()
    {
        var authorize = Assert.Single(typeof(AdminCustomersController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, authorize.Roles);
    }

    [Fact]
    public async Task Details_returns_only_target_accounts_cards_and_currency_balances()
    {
        await using var fixture = await Fixture.CreateAsync();
        var details = await new AdminCustomerService(
            fixture.Db, new UserSessionRevocationService(fixture.Db))
            .GetDetailsAsync(fixture.CustomerA.Id);

        Assert.Equal(4, details.Accounts.Count);
        Assert.DoesNotContain(details.Accounts, value => value.AccountNumber == "OTHER-ACCOUNT");
        Assert.Equal(3, details.Balances.Count);
        Assert.Equal(150m, details.Balances.Single(value => value.Currency == "USD").Amount);
        Assert.Equal(200m, details.Balances.Single(value => value.Currency == "EUR").Amount);
        Assert.Equal(300m, details.Balances.Single(value => value.Currency == "BAM").Amount);
        var card = Assert.Single(details.Accounts, value => value.Card != null).Card!;
        Assert.Equal("**** **** **** 3456", card.MaskedCardNumber);
        Assert.DoesNotContain("1234567890123456", card.MaskedCardNumber);
        Assert.Null(typeof(AdminCustomerCardResponse).GetProperty("Cvv"));
        Assert.Null(typeof(AdminCustomerCardResponse).GetProperty("CardNumber"));
    }

    [Fact]
    public async Task Unknown_customer_returns_not_found()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<NotFoundException>(() =>
            new AdminCustomerService(
                fixture.Db, new UserSessionRevocationService(fixture.Db))
                .GetDetailsAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task Customer_filters_are_server_side_and_paginated()
    {
        await using var fixture = await Fixture.CreateAsync();
        var admin = new CurrentUser(fixture.Admin.Id, true);
        var transactions = new TransactionService(fixture.Db, admin, new DemoCurrencyConversionService());
        var transactionPage = await transactions.GetAsync(new TransactionQueryRequest
        {
            CustomerId = fixture.CustomerA.Id, Page = 1, PageSize = 1
        });
        Assert.Single(transactionPage.Items);
        Assert.Equal(2, transactionPage.TotalCount);
        Assert.All(transactionPage.Items, value => Assert.StartsWith("A-", value.ReferenceNumber));

        var cardRequests = await new CardService(fixture.Db, admin).GetRequestsAsync(new CardRequestQueryRequest
        {
            CustomerId = fixture.CustomerA.Id, Page = 1, PageSize = 20
        });
        Assert.Single(cardRequests.Items);
        Assert.All(cardRequests.Items, value => Assert.Equal(fixture.CustomerA.Id, value.UserId));

        var loans = new AdminLoanService(fixture.Db, admin, new LoanCalculationService());
        var applications = await loans.GetApplicationsAsync(new AdminLoanApplicationQueryRequest
        {
            CustomerId = fixture.CustomerA.Id, Page = 1, PageSize = 20
        });
        Assert.Single(applications.Items);
        Assert.All(applications.Items, value => Assert.Equal(fixture.CustomerA.Id, value.CustomerId));
        var active = await loans.GetLoansAsync(new AdminLoanQueryRequest
        {
            CustomerId = fixture.CustomerA.Id, Status = LoanStatus.Active, Page = 1, PageSize = 20
        });
        Assert.Single(active.Items);
        Assert.All(active.Items, value => Assert.Equal(fixture.CustomerA.Id, value.CustomerId));
    }

    [Fact]
    public async Task Transaction_type_and_involved_account_filters_are_server_side()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new TransactionService(
            fixture.Db,
            new CurrentUser(fixture.Admin.Id, true),
            new DemoCurrencyConversionService());
        var account = await fixture.Db.Accounts.SingleAsync(value => value.AccountNumber == "A-USD");
        var destination = await fixture.Db.Accounts.SingleAsync(value => value.AccountNumber == "A-EUR");
        fixture.Db.Transactions.Add(new Transaction
        {
            Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
            SourceAccountId = account.Id, DestinationAccountId = destination.Id,
            ReferenceNumber = "INTERNAL-1", Amount = 25,
            Type = TransactionType.InternalTransfer,
            Description = "Internal", Status = TransactionStatus.Completed,
            CreatedAtUtc = DateTime.UtcNow
        });
        await fixture.Db.SaveChangesAsync();

        var byType = await service.GetAsync(new TransactionQueryRequest
        {
            Type = TransactionType.InternalTransfer, Page = 1, PageSize = 20
        });
        Assert.Single(byType.Items);
        var internalTransfer = Assert.Single(byType.Items);
        Assert.Equal(TransactionType.InternalTransfer, internalTransfer.Type);
        Assert.Equal("USD", internalTransfer.Currency);

        var byDestination = await service.GetAsync(new TransactionQueryRequest
        {
            AccountId = destination.Id, Page = 1, PageSize = 20
        });
        Assert.Contains(byDestination.Items, value => value.ReferenceNumber == "INTERNAL-1");
    }

    [Fact]
    public async Task Card_operations_are_safe_filtered_and_show_approved_result()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new CardService(fixture.Db, new CurrentUser(fixture.Admin.Id, true));

        var futureRequests = await service.GetRequestsAsync(new CardRequestQueryRequest
        {
            DateFromUtc = DateTime.UtcNow.AddDays(1), Page = 1, PageSize = 20
        });
        Assert.Empty(futureRequests.Items);

        var request = await fixture.Db.CardRequests.FirstAsync(value => value.UserId == fixture.CustomerA.Id);
        var approved = await service.ApproveAsync(request.Id, new CardRequestReviewRequest { AdminNote = "Approved" });
        Assert.NotNull(approved.ApprovedAccountNumber);
        Assert.StartsWith("**** **** **** ", approved.ApprovedMaskedCardNumber);
        Assert.NotNull(approved.ApprovedCardExpiryDate);
        Assert.Equal(CardStatus.Active, approved.ApprovedCardStatus);

        var cards = await service.GetIssuedCardsAsync(new AdminIssuedCardQueryRequest
        {
            Search = "Alpha", Page = 1, PageSize = 20
        });
        Assert.Equal(2, cards.TotalCount);
        Assert.All(cards.Items, value => Assert.Equal(fixture.CustomerA.Id, value.CustomerId));
        Assert.All(cards.Items, value => Assert.StartsWith("**** **** **** ", value.MaskedCardNumber));
        Assert.Null(typeof(AdminIssuedCardResponse).GetProperty("Cvv"));
        Assert.Null(typeof(AdminIssuedCardResponse).GetProperty("CardNumber"));
    }

    [Fact]
    public async Task Loan_application_date_range_is_applied()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new AdminLoanService(
            fixture.Db,
            new CurrentUser(fixture.Admin.Id, true),
            new LoanCalculationService());
        var result = await service.GetApplicationsAsync(new AdminLoanApplicationQueryRequest
        {
            DateFromUtc = DateTime.UtcNow.AddDays(1), Page = 1, PageSize = 20
        });
        Assert.Empty(result.Items);
    }

    [Fact]
    public void Issued_cards_controller_is_admin_only()
    {
        var authorize = Assert.Single(typeof(AdminCardsController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, authorize.Roles);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User a, User admin) { Db = db; CustomerA = a; Admin = admin; }
        public BankingAppDbContext Db { get; }
        public User CustomerA { get; }
        public User Admin { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var a = User("Alpha", AppRoles.Customer);
            var b = User("Beta", AppRoles.Customer);
            var admin = User("Admin", AppRoles.Admin);
            var usd = Account(a, "A-USD", "USD", 100);
            var usd2 = Account(a, "A-USD-2", "USD", 50);
            var eur = Account(a, "A-EUR", "EUR", 200);
            var bam = Account(a, "A-BAM", "BAM", 300);
            var other = Account(b, "OTHER-ACCOUNT", "USD", 999);
            var card = new BankCard { Id = Guid.NewGuid(), AccountId = usd.Id, Account = usd, CardNumber = "1234567890123456", CardholderName = "Alpha User", Cvv = "999", ExpiryDate = DateTime.UtcNow.AddYears(3), Brand = CardBrand.Mastercard, Status = CardStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            usd.Card = card;
            var product = new LoanProduct { Id = Guid.NewGuid(), Name = "Personal", Currency = "USD", AnnualInterestRate = 5, MinPrincipal = 100, MaxPrincipal = 10000, MinTermMonths = 6, MaxTermMonths = 24, TermStepMonths = 6, IsActive = true, CreatedAtUtc = DateTime.UtcNow };
            var appA = Application(a, usd, product);
            var appB = Application(b, other, product);
            var loanA = Loan(a, usd, appA);
            var loanB = Loan(b, other, appB);
            db.Users.AddRange(a, b, admin); db.Accounts.AddRange(usd, usd2, eur, bam, other); db.BankCards.Add(card); db.LoanProducts.Add(product); db.LoanApplications.AddRange(appA, appB); db.Loans.AddRange(loanA, loanB);
            db.CardRequests.AddRange(Request(a), Request(b));
            db.Transactions.AddRange(Transaction(usd, "A-1"), Transaction(eur, "A-2"), Transaction(other, "B-1"));
            await db.SaveChangesAsync(); return new Fixture(db, a, admin);
        }
        private static User User(string name, string role) => new() { Id = Guid.NewGuid(), FirstName = name, LastName = "User", Email = $"{Guid.NewGuid()}@test.com", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = role, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
        private static Account Account(User user, string number, string currency, decimal balance) => new() { Id = Guid.NewGuid(), UserId = user.Id, User = user, AccountNumber = number, Currency = currency, Balance = balance, AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow };
        private static Transaction Transaction(Account account, string reference) => new() { Id = Guid.NewGuid(), AccountId = account.Id, Account = account, ReferenceNumber = reference, Amount = 10, Type = TransactionType.Transfer, Description = "Test", Status = TransactionStatus.Completed, CreatedAtUtc = DateTime.UtcNow };
        private static CardRequest Request(User user) => new() { Id = Guid.NewGuid(), UserId = user.Id, User = user, CardholderName = user.FirstName, Currency = "USD", DocumentNumber = "DOC", DeliveryAddress = "Address", Note = "", Status = CardRequestStatus.Pending, CreatedAtUtc = DateTime.UtcNow };
        private static LoanApplication Application(User user, Account account, LoanProduct product) => new() { Id = Guid.NewGuid(), UserId = user.Id, User = user, LoanProductId = product.Id, LoanProduct = product, DestinationAccountId = account.Id, DestinationAccount = account, Principal = 1000, Currency = "USD", AnnualInterestRateSnapshot = 5, TermMonths = 12, EstimatedMonthlyPayment = 90, EstimatedTotalInterest = 80, EstimatedTotalRepayment = 1080, Status = LoanApplicationStatus.Approved, SubmittedAtUtc = DateTime.UtcNow, ClientRequestId = Guid.NewGuid() };
        private static Loan Loan(User user, Account account, LoanApplication application) => new() { Id = Guid.NewGuid(), LoanApplicationId = application.Id, LoanApplication = application, UserId = user.Id, User = user, DestinationAccountId = account.Id, DestinationAccount = account, OriginalPrincipal = 1000, OutstandingPrincipal = 800, Currency = "USD", AnnualInterestRate = 5, TermMonths = 12, MonthlyPayment = 90, TotalRepayment = 1080, TotalPaid = 280, StartDateUtc = DateTime.UtcNow.AddMonths(-2), NextPaymentDateUtc = DateTime.UtcNow.AddMonths(1), MaturityDateUtc = DateTime.UtcNow.AddMonths(10), Status = LoanStatus.Active, CreatedAtUtc = DateTime.UtcNow.AddMonths(-2) };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => admin; }
}
