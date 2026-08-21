using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class InternalTransferTests
{
    [Fact]
    public async Task Transfer_moves_money_between_two_owned_accounts_and_writes_paired_history()
    {
        await using var fixture = await Fixture.CreateAsync();

        var result = await fixture.Service.InternalTransferAsync(new InternalTransferRequest
        {
            SourceAccountId = fixture.Source.Id,
            DestinationAccountId = fixture.Destination.Id,
            Amount = 25,
            Description = "Savings"
        });

        Assert.Equal(TransactionStatus.Completed, result.Status);
        Assert.Equal(75, fixture.Source.Balance);
        Assert.Equal(25, fixture.Destination.Balance);
        Assert.False(result.DebitTransaction.IsHighRiskReview);
        Assert.Equal(result.DebitTransaction.ReferenceNumber, result.CreditTransaction.ReferenceNumber);
        Assert.Equal(-25, result.DebitTransaction.Amount);
        Assert.Equal(25, result.CreditTransaction.Amount);
        Assert.Equal(TransactionType.InternalTransfer, result.DebitTransaction.Type);
        Assert.Equal(TransactionType.InternalTransfer, result.CreditTransaction.Type);
        Assert.Equal(2, await fixture.Db.Transactions.CountAsync());
    }

    [Theory]
    [InlineData("USD", "EUR")]
    [InlineData("USD", "BAM")]
    [InlineData("EUR", "USD")]
    [InlineData("EUR", "BAM")]
    [InlineData("BAM", "USD")]
    [InlineData("BAM", "EUR")]
    public async Task Cross_currency_quote_and_transfer_use_the_same_central_fx_result(
        string sourceCurrency,
        string destinationCurrency)
    {
        await using var fixture = await Fixture.CreateAsync(
            sourceBalance: 20000,
            sourceCurrency: sourceCurrency,
            destinationCurrency: destinationCurrency);
        var request = new InternalTransferRequest
        {
            SourceAccountId = fixture.Source.Id,
            DestinationAccountId = fixture.Destination.Id,
            Amount = 100
        };

        var quote = await fixture.Service.QuoteInternalTransferAsync(request);
        var result = await fixture.Service.InternalTransferAsync(request);

        Assert.True(quote.RequiresConversion);
        Assert.Equal(sourceCurrency, quote.TransferCurrency);
        Assert.Equal(destinationCurrency, quote.DestinationCurrency);
        Assert.Equal(quote.DebitAmount, result.Quote.DebitAmount);
        Assert.Equal(quote.DestinationAmount, result.Quote.DestinationAmount);
        Assert.Equal(20000 - quote.DebitAmount, fixture.Source.Balance);
        Assert.Equal(quote.DestinationAmount, fixture.Destination.Balance);
    }

    [Fact]
    public async Task Same_currency_transfer_has_no_conversion()
    {
        await using var fixture = await Fixture.CreateAsync();
        var quote = await fixture.Service.QuoteInternalTransferAsync(fixture.Request(10));

        Assert.False(quote.RequiresConversion);
        Assert.Equal(1, quote.ExchangeRate);
        Assert.Equal(10, quote.DestinationAmount);
    }

    [Fact]
    public async Task Same_account_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var request = fixture.Request(10);
        request.DestinationAccountId = fixture.Source.Id;

        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(request));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task Non_positive_amount_is_rejected(decimal amount)
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(fixture.Request(amount)));
    }

    [Fact]
    public async Task Insufficient_balance_leaves_balances_and_history_unchanged()
    {
        await using var fixture = await Fixture.CreateAsync(sourceBalance: 10);

        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(fixture.Request(11)));
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.InternalTransferAsync(fixture.Request(11)));

        Assert.Equal(10, fixture.Source.Balance);
        Assert.Equal(0, fixture.Destination.Balance);
        Assert.Empty(await fixture.Db.Transactions.ToListAsync());
    }

    [Fact]
    public async Task Source_and_destination_must_both_belong_to_current_customer()
    {
        await using var fixture = await Fixture.CreateAsync();

        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(new InternalTransferQuoteRequest
            {
                SourceAccountId = fixture.OtherAccount.Id,
                DestinationAccountId = fixture.Destination.Id,
                Amount = 10
            }));
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(new InternalTransferQuoteRequest
            {
                SourceAccountId = fixture.Source.Id,
                DestinationAccountId = fixture.OtherAccount.Id,
                Amount = 10
            }));
    }

    [Fact]
    public async Task Large_internal_transfer_is_completed_without_high_risk_review()
    {
        await using var fixture = await Fixture.CreateAsync(sourceBalance: 20000);
        var result = await fixture.Service.InternalTransferAsync(fixture.Request(15000));

        Assert.Equal(TransactionStatus.Completed, result.Status);
        Assert.False(result.DebitTransaction.IsHighRiskReview);
        Assert.Equal(5000, fixture.Source.Balance);
        Assert.Equal(15000, fixture.Destination.Balance);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Transfer_is_account_based_and_does_not_require_an_active_card(bool addBlockedCard)
    {
        await using var fixture = await Fixture.CreateAsync(addBlockedCard: addBlockedCard);
        var result = await fixture.Service.InternalTransferAsync(fixture.Request(10));
        Assert.Equal(TransactionStatus.Completed, result.Status);
    }

    [Fact]
    public async Task Unsupported_account_currency_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync(destinationCurrency: "GBP");
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.QuoteInternalTransferAsync(fixture.Request(10)));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, Account source,
            Account destination, Account otherAccount)
        {
            Db = db;
            Source = source;
            Destination = destination;
            OtherAccount = otherAccount;
            Service = new TransactionService(
                db,
                new CurrentUser(owner.Id),
                new DemoCurrencyConversionService());
        }

        public BankingAppDbContext Db { get; }
        public TransactionService Service { get; }
        public Account Source { get; }
        public Account Destination { get; }
        public Account OtherAccount { get; }

        public InternalTransferRequest Request(decimal amount) => new()
        {
            SourceAccountId = Source.Id,
            DestinationAccountId = Destination.Id,
            Amount = amount
        };

        public static async Task<Fixture> CreateAsync(
            decimal sourceBalance = 100,
            string sourceCurrency = "USD",
            string destinationCurrency = "USD",
            bool addBlockedCard = false)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var other = User("Other");
            var source = Account(owner, "source", sourceBalance, sourceCurrency);
            var destination = Account(owner, "destination", 0, destinationCurrency);
            var otherAccount = Account(other, "other", 0, "USD");
            db.Users.AddRange(owner, other);
            db.Accounts.AddRange(source, destination, otherAccount);
            if (addBlockedCard)
            {
                db.BankCards.Add(new BankCard
                {
                    Id = Guid.NewGuid(),
                    AccountId = source.Id,
                    Account = source,
                    CardNumber = "4562000000000675",
                    CardholderName = "Owner Customer",
                    Cvv = "123",
                    ExpiryDate = DateTime.UtcNow.AddYears(4),
                    Brand = CardBrand.Mastercard,
                    Status = CardStatus.Blocked,
                    CreatedAtUtc = DateTime.UtcNow
                });
            }
            await db.SaveChangesAsync();
            return new Fixture(db, owner, source, destination, otherAccount);
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(),
            FirstName = name,
            LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com",
            PhoneNumber = "+38761000000",
            PasswordHash = "hash",
            Role = AppRoles.Customer,
            Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(
            User user,
            string number,
            decimal balance,
            string currency) => new()
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            User = user,
            AccountNumber = number,
            Currency = currency,
            Balance = balance,
            AccountType = AccountType.Checking,
            CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
