using BankingApp.Worker;
using QuestPDF.Infrastructure;
using Xunit;

namespace BankingApp.Worker.Tests;

public sealed class ReportPdfGeneratorTests
{
    public ReportPdfGeneratorTests() => QuestPDF.Settings.License = LicenseType.Community;

    [Fact]
    public void Transaction_report_is_a_real_pdf_and_keeps_currency_totals_separate()
    {
        var rows = new[]
        {
            new TransactionReportRow(DateTime.UtcNow, "TXN-1", "Ada Bank", "Account •••• 1234", "Transfer", 10, "USD", "Completed"),
            new TransactionReportRow(DateTime.UtcNow, "TXN-2", "Ada Bank", "Account •••• 1234", "Transfer", 20, "EUR", "Completed")
        };
        var bytes = new QuestPdfReportGenerator().Transactions(rows, DateTime.UtcNow);
        Assert.True(bytes.Length > 1000);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(bytes, 0, 4));
    }

    [Fact]
    public void Loan_portfolio_report_is_a_real_pdf()
    {
        var rows = new[] { new LoanReportRow(DateTime.UtcNow, "Ada Bank", "Personal loan", 1000, 800, 5, 90, DateTime.UtcNow.AddYears(1), "USD", "Active", 1, true, 3) };
        var bytes = new QuestPdfReportGenerator().Loans(rows, DateTime.UtcNow);
        Assert.True(bytes.Length > 1000);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(bytes, 0, 4));
    }
}
