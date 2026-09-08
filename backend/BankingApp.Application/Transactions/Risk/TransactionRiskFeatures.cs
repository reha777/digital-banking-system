namespace BankingApp.Application.Transactions.Risk;

public sealed record TransactionRiskFeatures(
    double AmountBamNormalized,
    double SourceBalanceRatio,
    double OutgoingVelocity24Hours,
    double OutgoingVolume7Days,
    double HistoricalAmountDeviation,
    double NewRecipient,
    double AdverseHistory30Days);
