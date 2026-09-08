namespace BankingApp.Application.Transactions.Risk;

public interface ITransactionRiskService
{
    Task<TransactionRiskResult> EvaluateAsync(
        TransactionRiskContext context,
        CancellationToken cancellationToken = default);
}
