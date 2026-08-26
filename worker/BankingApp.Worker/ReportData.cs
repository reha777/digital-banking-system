namespace BankingApp.Worker;

public sealed record TransactionReportRow(DateTime Date, string Reference, string Customer, string AccountSummary, string Type, decimal Amount, string Currency, string Status);
public sealed record LoanReportRow(DateTime Date, string Customer, string Product, decimal Principal, decimal Outstanding, decimal InterestRate, decimal MonthlyPayment, DateTime MaturityDate, string Currency, string Status, int OverdueCount, bool IsOverdue, int DaysOverdue);

public interface IReportPdfGenerator
{
    byte[] Transactions(IReadOnlyList<TransactionReportRow> rows, DateTime generatedAtUtc);
    byte[] Loans(IReadOnlyList<LoanReportRow> rows, DateTime generatedAtUtc);
}
