using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Loans;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class LoanProductQuoteTests
{
    [Fact]
    public async Task Products_returns_only_active_items_sorted_by_currency()
    {
        await using var fixture = await Fixture.CreateAsync();
        var result = await fixture.Service.GetActiveProductsAsync(new PagedRequest());

        Assert.Equal(3, result.TotalCount);
        Assert.Equal(["BAM", "EUR", "USD"], result.Items.Select(value => value.Currency));
        Assert.DoesNotContain(result.Items, value => value.Id == fixture.Inactive.Id);
    }

    [Theory]
    [InlineData("BAM", 1000, 6)]
    [InlineData("EUR", 500, 12)]
    [InlineData("USD", 25000, 60)]
    public async Task Quote_supports_all_seed_currencies(string currency, decimal principal, int term)
    {
        await using var fixture = await Fixture.CreateAsync();
        var product = fixture.Products.Single(value => value.Currency == currency);
        var result = await fixture.Service.QuoteAsync(new LoanQuoteRequest
        {
            LoanProductId = product.Id,
            Principal = principal,
            TermMonths = term
        });

        Assert.Equal(currency, result.Currency);
        Assert.Equal(principal, result.Principal);
        Assert.Equal(term, result.Schedule.Count);
        Assert.Empty(fixture.Db.LoanApplications);
        Assert.Empty(fixture.Db.Loans);
    }

    [Theory]
    [InlineData(999, 6)]
    [InlineData(50001, 6)]
    [InlineData(1000.001, 6)]
    [InlineData(1000, 7)]
    [InlineData(1000, 66)]
    public async Task Invalid_amount_or_term_is_rejected(decimal principal, int term)
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.QuoteAsync(new LoanQuoteRequest
        {
            LoanProductId = fixture.Products.Single(value => value.Currency == "BAM").Id,
            Principal = principal,
            TermMonths = term
        }));
    }

    [Fact]
    public async Task Inactive_product_quote_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.QuoteAsync(new LoanQuoteRequest
        {
            LoanProductId = fixture.Inactive.Id,
            Principal = 1000,
            TermMonths = 6
        }));
    }

    [Fact]
    public async Task Unknown_product_quote_is_rejected()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Service.QuoteAsync(new LoanQuoteRequest
        {
            LoanProductId = Guid.NewGuid(),
            Principal = 1000,
            TermMonths = 6
        }));
    }

    [Fact]
    public async Task Admin_cannot_use_customer_products_service()
    {
        await using var fixture = await Fixture.CreateAsync(admin: true);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.GetActiveProductsAsync(new PagedRequest()));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, LoanService service, List<LoanProduct> products, LoanProduct inactive)
        {
            Db = db;
            Service = service;
            Products = products;
            Inactive = inactive;
        }

        public BankingAppDbContext Db { get; }
        public LoanService Service { get; }
        public List<LoanProduct> Products { get; }
        public LoanProduct Inactive { get; }

        public static async Task<Fixture> CreateAsync(bool admin = false)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var products = new List<LoanProduct>
            {
                Product("BAM", 1000, 50000, 6.5m),
                Product("EUR", 500, 25000, 5.75m),
                Product("USD", 500, 25000, 6m)
            };
            var inactive = Product("BAM", 1000, 50000, 7m, false);
            db.LoanProducts.AddRange(products.Append(inactive));
            await db.SaveChangesAsync();
            return new Fixture(
                db,
                new LoanService(db, new CurrentUser(admin), new LoanCalculationService()),
                products,
                inactive);
        }

        private static LoanProduct Product(
            string currency,
            decimal minimum,
            decimal maximum,
            decimal rate,
            bool active = true) => new()
        {
            Id = Guid.NewGuid(),
            Name = $"Personal Loan {currency}",
            Description = "Test product",
            Currency = currency,
            MinPrincipal = minimum,
            MaxPrincipal = maximum,
            AnnualInterestRate = rate,
            MinTermMonths = 6,
            MaxTermMonths = 60,
            TermStepMonths = 6,
            IsActive = active,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    [Fact]
    public async Task Products_support_page_two_and_enforce_max_page_size()
    {
        await using var fixture = await Fixture.CreateAsync();
        var second = await fixture.Service.GetActiveProductsAsync(
            new PagedRequest { Page = 2, PageSize = 1 });
        var capped = await fixture.Service.GetActiveProductsAsync(
            new PagedRequest { PageSize = 1000 });

        Assert.Equal(3, second.TotalCount);
        Assert.Equal(3, second.TotalPages);
        Assert.Equal("EUR", second.Items.Single().Currency);
        Assert.Equal(100, capped.PageSize);
    }

    private sealed class CurrentUser(bool admin) : ICurrentUserService
    {
        public Guid UserId => Guid.NewGuid();
        public bool IsAdmin => admin;
    }
}
