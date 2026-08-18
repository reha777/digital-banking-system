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

public class CardSecurityTests
{
    [Fact]
    public async Task Customer_cannot_freeze_or_reveal_another_customers_card()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = new CardService(fixture.Db, new CurrentUser(fixture.Other.Id));

        await Assert.ThrowsAsync<NotFoundException>(() =>
            service.SetFrozenAsync(fixture.Card.Id, true));
        await Assert.ThrowsAsync<NotFoundException>(() =>
            service.GetSensitiveDataAsync(fixture.Card.Id));
    }

    [Theory]
    [InlineData(CardStatus.Blocked)]
    [InlineData(CardStatus.Expired)]
    public async Task Ineligible_card_account_cannot_send_money(CardStatus status)
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Card.Status = status;
        await fixture.Db.SaveChangesAsync();
        var service = Service(fixture);

        await Assert.ThrowsAsync<BusinessException>(() => service.SendMoneyAsync(new MoneyTransferRequest
        {
            SourceAccountId = fixture.Source.Id,
            DestinationAccountNumber = fixture.Destination.AccountNumber,
            Amount = 10,
            Currency = "USD"
        }));
    }

    [Fact]
    public async Task Active_card_transfer_is_completed()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = Service(fixture);
        var result = await service.SendMoneyAsync(Request(fixture, 10));
        Assert.Equal(TransactionStatus.Completed, result.Status);
    }

    [Fact]
    public async Task Insufficient_balance_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = Service(fixture);
        await Assert.ThrowsAsync<BusinessException>(() =>
            service.SendMoneyAsync(Request(fixture, 101)));
    }

    [Fact]
    public async Task High_risk_transfer_remains_pending_and_does_not_move_balance()
    {
        await using var fixture = await Fixture.CreateAsync(sourceBalance: 20000);
        var service = Service(fixture);
        var result = await service.SendMoneyAsync(Request(fixture, 10001));
        Assert.Equal(TransactionStatus.Pending, result.Status);
        Assert.Equal(20000, fixture.Source.Balance);
        Assert.Equal(0, fixture.Destination.Balance);
    }

    [Theory]
    [InlineData("USD", "USD", "USD")]
    [InlineData("EUR", "EUR", "EUR")]
    [InlineData("BAM", "BAM", "BAM")]
    [InlineData("USD", "EUR", "EUR")]
    [InlineData("EUR", "USD", "USD")]
    [InlineData("BAM", "EUR", "EUR")]
    [InlineData("EUR", "BAM", "BAM")]
    public async Task Quote_and_transfer_use_the_same_currency_logic(
        string sourceCurrency, string destinationCurrency, string transferCurrency)
    {
        await using var fixture = await Fixture.CreateAsync(
            sourceBalance: 1000,
            sourceCurrency: sourceCurrency,
            destinationCurrency: destinationCurrency);
        var service = Service(fixture);
        var quote = await service.QuoteAsync(new MoneyTransferQuoteRequest
        {
            SourceAccountId = fixture.Source.Id,
            DestinationAccountNumber = fixture.Destination.AccountNumber,
            Amount = 10,
            Currency = transferCurrency
        });
        var result = await service.SendMoneyAsync(new MoneyTransferRequest
        {
            SourceAccountId = fixture.Source.Id,
            DestinationAccountNumber = fixture.Destination.AccountNumber,
            Amount = 10,
            Currency = transferCurrency
        });
        Assert.Equal(quote.DebitAmount, result.Quote.DebitAmount);
        Assert.Equal(quote.DestinationAmount, result.Quote.DestinationAmount);
    }

    [Fact]
    public async Task Unsupported_transfer_currency_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => Service(fixture).QuoteAsync(
            new MoneyTransferQuoteRequest
            {
                SourceAccountId = fixture.Source.Id,
                DestinationAccountNumber = fixture.Destination.AccountNumber,
                Amount = 10,
                Currency = "GBP"
            }));
    }

    private static MoneyTransferRequest Request(Fixture fixture, decimal amount) => new()
    {
        SourceAccountId = fixture.Source.Id,
        DestinationAccountNumber = fixture.Destination.AccountNumber,
        Amount = amount,
        Currency = "USD"
    };

    private static TransactionService Service(Fixture fixture) =>
        new(fixture.Db, new CurrentUser(fixture.Owner.Id), new DemoCurrencyConversionService());

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User other,
            Account source, Account destination, BankCard card)
        {
            Db = db; Owner = owner; Other = other; Source = source;
            Destination = destination; Card = card;
        }
        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User Other { get; }
        public Account Source { get; }
        public Account Destination { get; }
        public BankCard Card { get; }

        public static async Task<Fixture> CreateAsync(
            decimal sourceBalance = 100,
            string sourceCurrency = "USD",
            string destinationCurrency = "USD")
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner"); var other = User("Other");
            var source = Account(owner, "source", sourceBalance, sourceCurrency);
            var destination = Account(other, "destination", 0, destinationCurrency);
            var card = new BankCard
            {
                Id = Guid.NewGuid(), AccountId = source.Id, Account = source,
                CardNumber = "4562000000000675", CardholderName = "Owner Customer",
                Cvv = "123", ExpiryDate = DateTime.UtcNow.AddYears(4),
                Brand = CardBrand.Mastercard, Status = CardStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(owner, other); db.Accounts.AddRange(source, destination);
            db.BankCards.Add(card); await db.SaveChangesAsync();
            return new Fixture(db, owner, other, source, destination, card);
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };
        private static Account Account(
            User user, string number, decimal balance, string currency) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, User = user,
            AccountNumber = number, Currency = currency, Balance = balance,
            AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow
        };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => false;
    }
}
