namespace BankingApp.Worker;

/// <summary>
/// One ledger entry. A standard transfer produces two of these (a debit and a
/// credit sharing a reference number), so <paramref name="CountsTowardVolume"/>
/// marks the single canonical row that the business volume summary counts.
/// </summary>
public sealed record TransactionReportRow(DateTime Date, string Reference, string Customer, string AccountSummary, string Type, decimal Amount, string Currency, string Status, bool CountsTowardVolume = true);
public sealed record LoanReportRow(DateTime Date, string Customer, string Product, decimal Principal, decimal Outstanding, decimal InterestRate, decimal MonthlyPayment, DateTime MaturityDate, string Currency, string Status, int OverdueCount, bool IsOverdue, int DaysOverdue);

public interface IReportPdfGenerator
{
    byte[] Transactions(IReadOnlyList<TransactionReportRow> rows, DateTime generatedAtUtc);
    byte[] Loans(IReadOnlyList<LoanReportRow> rows, DateTime generatedAtUtc);
}
