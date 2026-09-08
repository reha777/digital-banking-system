namespace BankingApp.Application.Transactions.Risk;

public sealed class TransactionRiskOptions
{
    public const string SectionName = "TransactionRisk";
    public const string CurrentModelVersion = "transaction-risk-logreg-v1";

    public decimal ReviewThreshold { get; set; } = 0.60m;
}
