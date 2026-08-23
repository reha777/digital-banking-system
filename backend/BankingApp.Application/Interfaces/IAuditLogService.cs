using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Interfaces;

public interface IAuditLogService
{
    Task RecordAsync(AuditLogRecordRequest request, CancellationToken cancellationToken = default);
    Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken cancellationToken = default);
}
