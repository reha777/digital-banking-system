using BankingApp.Application.Transactions.Risk;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BankingApp.Infrastructure.Services;

public sealed class TransactionRiskService(
    BankingAppDbContext dbContext,
    ICurrencyConversionService currencyConversionService,
    IOptions<TransactionRiskOptions> options) : ITransactionRiskService
{
    private readonly TransactionRiskOptions _options = options.Value;

    public async Task<TransactionRiskResult> EvaluateAsync(
        TransactionRiskContext context,
        CancellationToken cancellationToken = default)
    {
        var now = context.EvaluatedAtUtc;
        var dayAgo = now.AddHours(-24);
        var weekAgo = now.AddDays(-7);
        var monthAgo = now.AddDays(-30);
        var customerAccountIds = dbContext.Accounts
            .Where(account => account.UserId == context.UserId)
            .Select(account => account.Id);
        var outgoing = dbContext.Transactions.AsNoTracking().Where(transaction =>
            transaction.SourceAccountId.HasValue &&
            customerAccountIds.Contains(transaction.SourceAccountId.Value) &&
            transaction.CreatedAtUtc < now);

        var count24Hours = await outgoing.CountAsync(
            transaction => transaction.CreatedAtUtc >= dayAgo,
            cancellationToken);
        var volumeByCurrency = await outgoing
            .Where(transaction =>
                transaction.CreatedAtUtc >= weekAgo &&
                transaction.TransferCurrency != null &&
                transaction.TransferAmount.HasValue)
            .GroupBy(transaction => transaction.TransferCurrency!)
            .Select(group => new
            {
                Currency = group.Key,
                Amount = group.Sum(transaction => Math.Abs(transaction.TransferAmount!.Value))
            })
            .ToListAsync(cancellationToken);
        var historicalAverage = await outgoing
            .Where(transaction =>
                transaction.CreatedAtUtc >= monthAgo &&
                transaction.Status == TransactionStatus.Completed &&
                transaction.TransferCurrency == context.Currency &&
                transaction.TransferAmount.HasValue)
            .Select(transaction => (decimal?)Math.Abs(transaction.TransferAmount!.Value))
            .AverageAsync(cancellationToken) ?? 0m;
        var isKnownRecipient = await outgoing.AnyAsync(
            transaction =>
                transaction.DestinationAccountId == context.DestinationAccountId &&
                transaction.Status == TransactionStatus.Completed,
            cancellationToken);
        var adverseCount = await outgoing.CountAsync(
            transaction =>
                transaction.CreatedAtUtc >= monthAgo &&
                transaction.IsHighRiskReview &&
                transaction.Status == TransactionStatus.Failed,
            cancellationToken);

        var outgoingVolumeBam = volumeByCurrency.Sum(group =>
            currencyConversionService.ToBam(group.Amount, group.Currency));
        var deviation = historicalAverage <= 0
            ? 0d
            : Math.Max(0d, (double)(context.Amount / historicalAverage) - 1d);
        var features = new TransactionRiskFeatures(
            AmountBamNormalized: Clamp((double)(context.AmountBam / 10000m), 0d, 3d),
            SourceBalanceRatio: context.SourceBalance <= 0
                ? 2d
                : Clamp((double)(context.SourceDebitAmount / context.SourceBalance), 0d, 2d),
            OutgoingVelocity24Hours: Clamp(count24Hours / 5d, 0d, 2d),
            OutgoingVolume7Days: Clamp((double)(outgoingVolumeBam / 50000m), 0d, 3d),
            HistoricalAmountDeviation: Clamp(deviation, 0d, 3d),
            NewRecipient: isKnownRecipient ? 0d : 1d,
            AdverseHistory30Days: Clamp(adverseCount / 3d, 0d, 2d));
        var probability = decimal.Round(
            TransactionRiskLogisticModel.Probability(features),
            8,
            MidpointRounding.AwayFromZero);

        return new TransactionRiskResult(
            probability,
            probability >= _options.ReviewThreshold,
            TransactionRiskOptions.CurrentModelVersion,
            features);
    }

    private static double Clamp(double value, double minimum, double maximum) =>
        Math.Min(maximum, Math.Max(minimum, value));
}
