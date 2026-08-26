using System.Text.Json;
using BankingApp.Application.Loans;
using BankingApp.Application.Messaging;
using BankingApp.Application.Reports;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BankingApp.Worker;

public sealed class ReportGenerationHandler(BankingAppDbContext db, IReportPdfGenerator pdf, IOptions<ReportGenerationOptions> configured)
{
    public async Task HandleAsync(ReadOnlyMemory<byte> body, CancellationToken token)
    {
        var message = ReportGenerationMessageSerializer.Deserialize(body.Span) ?? throw new InvalidDataException("Invalid report generation message.");
        var job = await db.ReportJobs.SingleOrDefaultAsync(x => x.Id == message.JobId, token) ?? throw new InvalidDataException("Report job does not exist.");
        if (job.Status == ReportJobStatus.Completed && !string.IsNullOrWhiteSpace(job.StoragePath) && File.Exists(job.StoragePath)) return;

        job.Status = ReportJobStatus.Processing; job.StartedAtUtc = DateTime.UtcNow; job.ErrorMessage = null;
        await db.SaveChangesAsync(token);
        try
        {
            var generatedAt = DateTime.UtcNow;
            byte[] content;
            string prefix;
            if (job.Type == ReportType.TransactionReport) { content = await TransactionPdf(job, generatedAt, token); prefix = "transaction-report"; }
            else if (job.Type == ReportType.LoanPortfolioReport) { content = await LoanPdf(job, generatedAt, token); prefix = "loan-portfolio-report"; }
            else throw new InvalidDataException("Unsupported report type.");

            var directory = Path.GetFullPath(configured.Value.OutputDirectory); Directory.CreateDirectory(directory);
            var storagePath = Path.Combine(directory, $"{job.Id:N}.pdf"); var temporaryPath = storagePath + ".tmp";
            await File.WriteAllBytesAsync(temporaryPath, content, token); File.Move(temporaryPath, storagePath, true);
            job.FileName = $"{prefix}-{generatedAt:yyyyMMdd-HHmm}.pdf"; job.StoragePath = storagePath;
            job.Status = ReportJobStatus.Completed; job.CompletedAtUtc = DateTime.UtcNow; job.FailedAtUtc = null;
            await db.SaveChangesAsync(token);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            job.Status = ReportJobStatus.Failed; job.FailedAtUtc = DateTime.UtcNow; job.CompletedAtUtc = null;
            job.ErrorMessage = exception.Message.Length <= 500 ? exception.Message : exception.Message[..500];
            await db.SaveChangesAsync(token); throw;
        }
    }

    private async Task<byte[]> TransactionPdf(ReportJob job, DateTime now, CancellationToken token)
    {
        var filter = JsonSerializer.Deserialize<TransactionReportRequest>(job.FilterJson) ?? new();
        IQueryable<Transaction> query = db.Transactions.AsNoTracking().Include(x => x.Account).ThenInclude(x => x.User);
        if (filter.DateFrom.HasValue) query = query.Where(x => x.CreatedAtUtc >= filter.DateFrom.Value);
        if (filter.DateTo.HasValue) query = query.Where(x => x.CreatedAtUtc <= filter.DateTo.Value);
        if (filter.Status.HasValue) query = query.Where(x => x.Status == filter.Status.Value);
        if (filter.TransactionType.HasValue) query = query.Where(x => x.Type == filter.TransactionType.Value);
        if (!string.IsNullOrWhiteSpace(filter.Currency)) query = query.Where(x => (x.TransferCurrency ?? x.Account.Currency) == filter.Currency);
        var values = await query.OrderByDescending(x => x.CreatedAtUtc).Take(configured.Value.MaxRows + 1).ToListAsync(token);
        EnsureLimit(values.Count);
        var rows = values.Select(x => new TransactionReportRow(x.CreatedAtUtc, x.ReferenceNumber, $"{x.Account.User.FirstName} {x.Account.User.LastName}".Trim(), $"Account •••• {x.Account.AccountNumber[^Math.Min(4, x.Account.AccountNumber.Length)..]}", x.Type.ToString(), x.TransferAmount ?? x.Amount, x.TransferCurrency ?? x.Account.Currency, x.Status.ToString())).ToList();
        return pdf.Transactions(rows, now);
    }

    private async Task<byte[]> LoanPdf(ReportJob job, DateTime now, CancellationToken token)
    {
        var filter = JsonSerializer.Deserialize<LoanPortfolioReportRequest>(job.FilterJson) ?? new();
        IQueryable<Loan> query = db.Loans.AsNoTracking().Include(x => x.User).Include(x => x.LoanApplication).ThenInclude(x => x.LoanProduct).Include(x => x.Installments);
        if (filter.DateFrom.HasValue) query = query.Where(x => x.CreatedAtUtc >= filter.DateFrom.Value);
        if (filter.DateTo.HasValue) query = query.Where(x => x.CreatedAtUtc <= filter.DateTo.Value);
        if (filter.Status.HasValue) query = query.Where(x => x.Status == filter.Status.Value);
        if (!string.IsNullOrWhiteSpace(filter.Currency)) query = query.Where(x => x.Currency == filter.Currency);
        var values = await query.OrderByDescending(x => x.CreatedAtUtc).Take(configured.Value.MaxRows + 1).ToListAsync(token);
        EnsureLimit(values.Count);
        var rows = values.Select(x => { var overdueValues = x.Installments.Select(i => LoanOverdueCalculator.Calculate(i.Status, i.DueDateUtc, now)).Where(v => v.IsOverdue).ToList(); var days = overdueValues.Count == 0 ? 0 : overdueValues.Max(v => v.DaysOverdue); return new LoanReportRow(x.StartDateUtc, $"{x.User.FirstName} {x.User.LastName}".Trim(), x.LoanApplication.LoanProduct.Name, x.OriginalPrincipal, x.OutstandingPrincipal, x.AnnualInterestRate, x.MonthlyPayment, x.MaturityDateUtc, x.Currency, x.Status.ToString(), overdueValues.Count, overdueValues.Count > 0, days); }).Where(x => !filter.OverdueOnly || x.IsOverdue).ToList();
        return pdf.Loans(rows, now);
    }

    private void EnsureLimit(int count) { if (count > configured.Value.MaxRows) throw new InvalidOperationException($"Report exceeds the maximum of {configured.Value.MaxRows} rows. Narrow the filters and try again."); }
}
