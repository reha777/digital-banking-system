using System.Text.Json;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using BankingApp.Application.Reports;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class AdminReportService(BankingAppDbContext db, ICurrentUserService user, IReportGenerationPublisher publisher, IAuditLogService audit) : IAdminReportService
{
    public Task<ReportJobResponse> RequestTransactionAsync(TransactionReportRequest request, CancellationToken token = default) { ValidateDates(request.DateFrom, request.DateTo); return CreateAsync(ReportType.TransactionReport, request, token); }
    public Task<ReportJobResponse> RequestLoanAsync(LoanPortfolioReportRequest request, CancellationToken token = default) { ValidateDates(request.DateFrom, request.DateTo); return CreateAsync(ReportType.LoanPortfolioReport, request, token); }

    private async Task<ReportJobResponse> CreateAsync<T>(ReportType type, T filters, CancellationToken token)
    {
        EnsureAdmin(); var now = DateTime.UtcNow;
        var job = new ReportJob { Id = Guid.NewGuid(), Type = type, RequestedByUserId = user.UserId, Status = ReportJobStatus.Queued, RequestedAtUtc = now, FilterJson = JsonSerializer.Serialize(filters), CorrelationId = Guid.NewGuid().ToString("N") };
        db.ReportJobs.Add(job);
        await audit.RecordAsync(new AuditLogRecordRequest { Action = AuditLogActions.ReportRequested, EntityType = AuditEntityTypes.ReportJob, EntityId = job.Id.ToString(), Description = $"{type} generation requested.", CorrelationId = job.CorrelationId }, token);
        await db.SaveChangesAsync(token);
        try { await publisher.PublishAsync(new ReportGenerationRequested(job.Id, now), token); }
        catch (Exception exception) { job.Status = ReportJobStatus.Failed; job.FailedAtUtc = DateTime.UtcNow; job.ErrorMessage = "Report could not be queued: " + exception.Message[..Math.Min(exception.Message.Length, 450)]; await db.SaveChangesAsync(token); throw; }
        return await GetAsync(job.Id, token);
    }

    public async Task<ReportJobResponse> GetAsync(Guid id, CancellationToken token = default) { EnsureAdmin(); return Map(await Query().SingleOrDefaultAsync(x => x.Id == id, token) ?? throw new NotFoundException("Report job was not found.")); }
    public async Task<PagedResult<ReportJobResponse>> ListAsync(ReportJobQuery query, CancellationToken token = default)
    {
        EnsureAdmin(); var source = Query(); var total = await source.CountAsync(token); var items = await source.OrderByDescending(x => x.RequestedAtUtc).Skip((query.Page - 1) * query.PageSize).Take(query.PageSize).ToListAsync(token);
        return new PagedResult<ReportJobResponse> { Items = items.Select(Map).ToList(), Page = query.Page, PageSize = query.PageSize, TotalCount = total };
    }
    public async Task<ReportFileResponse> DownloadAsync(Guid id, CancellationToken token = default)
    {
        EnsureAdmin(); var job = await Query().SingleOrDefaultAsync(x => x.Id == id, token) ?? throw new NotFoundException("Report job was not found.");
        var expectedStorageName = $"{job.Id:N}.pdf";
        if (job.Status != ReportJobStatus.Completed || string.IsNullOrWhiteSpace(job.StoragePath) || !string.Equals(Path.GetFileName(job.StoragePath), expectedStorageName, StringComparison.OrdinalIgnoreCase) || !File.Exists(job.StoragePath)) throw new BusinessException("Report is not available for download.");
        return new ReportFileResponse(await File.ReadAllBytesAsync(job.StoragePath, token), job.FileName ?? $"{id}.pdf");
    }
    private IQueryable<ReportJob> Query() => db.ReportJobs.AsNoTracking().Include(x => x.RequestedByUser);
    private void EnsureAdmin() { if (!user.IsAdmin) throw new UnauthorizedAccessException(); }
    private static void ValidateDates(DateTime? from, DateTime? to) { if (from.HasValue && to.HasValue && from > to) throw new BusinessException("Date from must be before date to."); }
    private static ReportJobResponse Map(ReportJob job) => new() { Id = job.Id, Type = job.Type.ToString(), Status = job.Status.ToString(), RequestedBy = $"{job.RequestedByUser.FirstName} {job.RequestedByUser.LastName}".Trim(), RequestedAtUtc = job.RequestedAtUtc, CompletedAtUtc = job.CompletedAtUtc, FileName = job.FileName, DownloadAvailable = job.Status == ReportJobStatus.Completed, ErrorMessage = job.ErrorMessage };
}
