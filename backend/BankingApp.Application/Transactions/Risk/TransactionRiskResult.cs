namespace BankingApp.Application.Transactions.Risk;

public sealed record TransactionRiskResult(
    decimal Probability,
    bool IsHighRisk,
    string ModelVersion,
    TransactionRiskFeatures Features);
