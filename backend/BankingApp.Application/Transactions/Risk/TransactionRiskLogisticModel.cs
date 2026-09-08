namespace BankingApp.Application.Transactions.Risk;

public static class TransactionRiskLogisticModel
{
    public const double Intercept = -3.9;
    public const double AmountBamWeight = 3.0;
    public const double SourceBalanceRatioWeight = 1.2;
    public const double OutgoingVelocity24HoursWeight = 0.8;
    public const double OutgoingVolume7DaysWeight = 0.7;
    public const double HistoricalAmountDeviationWeight = 0.7;
    public const double NewRecipientWeight = 0.8;
    public const double AdverseHistory30DaysWeight = 1.0;

    public static decimal Probability(TransactionRiskFeatures features)
    {
        var score = Intercept +
            AmountBamWeight * features.AmountBamNormalized +
            SourceBalanceRatioWeight * features.SourceBalanceRatio +
            OutgoingVelocity24HoursWeight * features.OutgoingVelocity24Hours +
            OutgoingVolume7DaysWeight * features.OutgoingVolume7Days +
            HistoricalAmountDeviationWeight * features.HistoricalAmountDeviation +
            NewRecipientWeight * features.NewRecipient +
            AdverseHistory30DaysWeight * features.AdverseHistory30Days;

        var probability = score >= 0
            ? 1d / (1d + Math.Exp(-score))
            : Math.Exp(score) / (1d + Math.Exp(score));
        return decimal.Clamp((decimal)probability, 0m, 1m);
    }
}
