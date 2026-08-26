using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class LoanRecommendationService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUserService) : ILoanRecommendationService
{
    // 100 total: activity 25, inflow 15, balance 10, interest 30, term flexibility 20.
    private const int ActivityWeight = 25;
    private const int InflowWeight = 15;
    private const int BalanceWeight = 10;
    private const int InterestWeight = 30;
    private const int TermFlexibilityWeight = 20;

    public async Task<LoanRecommendationResponse> GetRecommendationsAsync(
        CancellationToken cancellationToken = default)
    {
        var userId = currentUserService.UserId;
        if (await dbContext.Loans.AsNoTracking().AnyAsync(
            loan => loan.UserId == userId && loan.Status == LoanStatus.Active,
            cancellationToken))
            return Blocked("A new recommendation is unavailable while you have an active loan.");

        if (await dbContext.LoanApplications.AsNoTracking().AnyAsync(
            application => application.UserId == userId &&
                application.Status == LoanApplicationStatus.Pending,
            cancellationToken))
            return Blocked("A new recommendation is unavailable while your application is pending.");

        var accounts = await dbContext.Accounts.AsNoTracking()
            .Where(account => account.UserId == userId)
            .GroupBy(account => account.Currency)
            .Select(group => new AccountSignal(
                group.Key.ToUpper(),
                group.Sum(account => account.Balance)))
            .ToListAsync(cancellationToken);
        var currencies = accounts.Select(account => account.Currency).ToHashSet();

        var products = await dbContext.LoanProducts.AsNoTracking()
            .Where(product => product.IsActive &&
                product.MinPrincipal > 0 && product.MaxPrincipal >= product.MinPrincipal &&
                product.AnnualInterestRate >= 0 &&
                product.MinTermMonths > 0 && product.MaxTermMonths >= product.MinTermMonths &&
                product.TermStepMonths > 0)
            .Where(product => currencies.Contains(product.Currency.ToUpper()))
            .ToListAsync(cancellationToken);
        if (products.Count == 0)
            return new LoanRecommendationResponse { CanApply = true };

        var sinceUtc = DateTime.UtcNow.AddDays(-90);
        var activity = await dbContext.Transactions.AsNoTracking()
            .Where(transaction => transaction.Account.UserId == userId &&
                transaction.Status == TransactionStatus.Completed &&
                transaction.CreatedAtUtc >= sinceUtc)
            .GroupBy(transaction => transaction.Account.Currency)
            .Select(group => new ActivitySignal(
                group.Key.ToUpper(),
                group.Count(),
                group.Where(transaction => transaction.Amount > 0)
                    .Sum(transaction => transaction.Amount)))
            .ToListAsync(cancellationToken);

        var minimumRate = products.Min(product => product.AnnualInterestRate);
        var maximumRate = products.Max(product => product.AnnualInterestRate);
        var maximumTermRange = Math.Max(1, products.Max(product =>
            product.MaxTermMonths - product.MinTermMonths));
        var accountByCurrency = accounts.ToDictionary(value => value.Currency);
        var activityByCurrency = activity.ToDictionary(value => value.Currency);

        var ranked = products.Select(product =>
        {
            var currency = product.Currency.ToUpperInvariant();
            var account = accountByCurrency[currency];
            activityByCurrency.TryGetValue(currency, out var signal);
            var reasons = new List<string> { $"Matches your {currency} account" };
            var score = 0m;

            if (signal is { Count: > 0 })
            {
                score += Math.Min(ActivityWeight, signal.Count * 5);
                reasons.Add("Your recent account activity matches this product");
            }
            if (signal is { IncomingTotal: > 0 })
            {
                score += InflowWeight;
                reasons.Add("Recent completed inflows were detected in this currency");
            }
            if (account.Balance > 0) score += BalanceWeight;

            score += maximumRate == minimumRate
                ? InterestWeight
                : InterestWeight * (maximumRate - product.AnnualInterestRate) /
                    (maximumRate - minimumRate);
            if (product.AnnualInterestRate == minimumRate)
                reasons.Add("Offers a lower interest rate among eligible products");

            var termRange = product.MaxTermMonths - product.MinTermMonths;
            score += TermFlexibilityWeight * termRange / maximumTermRange;
            if (termRange > 0) reasons.Add("Offers flexible repayment terms");

            return new Candidate(product, (int)Math.Clamp(Math.Round(score), 0, 100), reasons);
        }).OrderByDescending(candidate => candidate.Score)
            .ThenBy(candidate => candidate.Product.AnnualInterestRate)
            .ThenBy(candidate => candidate.Product.Name)
            .ThenBy(candidate => candidate.Product.Id)
            .Take(3)
            .ToList();

        return new LoanRecommendationResponse
        {
            CanApply = true,
            Recommendations = ranked.Select((candidate, index) =>
                new LoanRecommendationItemResponse
                {
                    ProductId = candidate.Product.Id,
                    ProductName = candidate.Product.Name,
                    Score = candidate.Score,
                    Rank = index + 1,
                    Reasons = candidate.Reasons.Take(3).ToList(),
                    Currency = candidate.Product.Currency,
                    InterestRate = candidate.Product.AnnualInterestRate,
                    MinAmount = candidate.Product.MinPrincipal,
                    MaxAmount = candidate.Product.MaxPrincipal,
                    MinTermMonths = candidate.Product.MinTermMonths,
                    MaxTermMonths = candidate.Product.MaxTermMonths
                }).ToList()
        };
    }

    private static LoanRecommendationResponse Blocked(string reason) => new()
    {
        CanApply = false,
        BlockReason = reason
    };

    private sealed record AccountSignal(string Currency, decimal Balance);
    private sealed record ActivitySignal(string Currency, int Count, decimal IncomingTotal);
    private sealed record Candidate(
        BankingApp.Domain.Entities.LoanProduct Product,
        int Score,
        IReadOnlyCollection<string> Reasons);
}
