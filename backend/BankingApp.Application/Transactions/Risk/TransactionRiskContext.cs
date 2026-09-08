namespace BankingApp.Application.Transactions.Risk;

public sealed record TransactionRiskContext(
    Guid UserId,
    Guid SourceAccountId,
    Guid DestinationAccountId,
    decimal Amount,
    string Currency,
    decimal AmountBam,
    decimal SourceDebitAmount,
    decimal SourceBalance,
    DateTime EvaluatedAtUtc);
