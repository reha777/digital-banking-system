using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace BankingApp.Worker;

public sealed class QuestPdfReportGenerator : IReportPdfGenerator
{
    public byte[] Transactions(IReadOnlyList<TransactionReportRow> rows, DateTime generatedAtUtc) =>
        Build("Transaction Report", generatedAtUtc, new[] { $"Total: {rows.Count}", $"Completed: {rows.Count(x => x.Status == "Completed")}", $"Pending: {rows.Count(x => x.Status == "Pending")}", $"Failed: {rows.Count(x => x.Status == "Failed")}" }.Concat(rows.Where(x => x.Status == "Completed").GroupBy(x => x.Currency).Select(x => $"Completed {x.Key}: {x.Sum(v => v.Amount):N2}")),
            new[] { "Date", "Reference", "Customer", "Account", "Type", "Amount", "Status" },
            rows.Select(x => new[] { x.Date.ToString("yyyy-MM-dd HH:mm"), x.Reference, x.Customer, x.AccountSummary, x.Type, $"{x.Currency} {x.Amount:N2}", x.Status }));

    public byte[] Loans(IReadOnlyList<LoanReportRow> rows, DateTime generatedAtUtc) =>
        Build("Loan Portfolio Report", generatedAtUtc, new[] { $"Active: {rows.Count(x => x.Status == "Active")}", $"Completed: {rows.Count(x => x.Status == "Completed")}", $"With overdue installments: {rows.Count(x => x.IsOverdue)}" }.Concat(rows.GroupBy(x => x.Currency).Select(x => $"{x.Key}: disbursed {x.Sum(v => v.Principal):N2}, outstanding {x.Sum(v => v.Outstanding):N2}")),
            new[] { "Customer", "Product", "Principal", "Outstanding", "Rate", "Monthly", "Start / Maturity", "Status", "Overdue" },
            rows.Select(x => new[] { x.Customer, x.Product, $"{x.Currency} {x.Principal:N2}", $"{x.Currency} {x.Outstanding:N2}", $"{x.InterestRate:N2}%", $"{x.Currency} {x.MonthlyPayment:N2}", $"{x.Date:yyyy-MM-dd} / {x.MaturityDate:yyyy-MM-dd}", x.Status, x.IsOverdue ? $"{x.OverdueCount} ({x.DaysOverdue} days)" : "0" }));

    private static byte[] Build(string title, DateTime generatedAtUtc, IEnumerable<string> summaries, string[] headers, IEnumerable<string[]> rows)
    {
        return Document.Create(document => document.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape()); page.Margin(28); page.DefaultTextStyle(x => x.FontSize(8).FontColor(Colors.Grey.Darken3));
            page.Header().Column(column => { column.Item().Text(title).FontSize(20).SemiBold().FontColor(Colors.Blue.Darken3); column.Item().Text($"Generated {generatedAtUtc:yyyy-MM-dd HH:mm} UTC").FontColor(Colors.Grey.Medium); });
            page.Content().PaddingVertical(16).Column(column =>
            {
                column.Spacing(10); column.Item().Text(string.Join("   |   ", summaries.DefaultIfEmpty("No financial totals"))).SemiBold();
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns => { foreach (var _ in headers) columns.RelativeColumn(); });
                    table.Header(header => { foreach (var value in headers) header.Cell().Background(Colors.Blue.Darken3).Padding(6).Text(value).FontColor(Colors.White).SemiBold(); });
                    var index = 0; foreach (var row in rows) { foreach (var value in row) table.Cell().Background(index % 2 == 0 ? Colors.Grey.Lighten4 : Colors.White).BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten2).Padding(5).Text(value); index++; }
                });
            });
            page.Footer().AlignCenter().Text(text => { text.Span("Digital Banking System  •  "); text.CurrentPageNumber(); text.Span(" / "); text.TotalPages(); });
        })).GeneratePdf();
    }
}
