using BankingApp.Application.Messaging;

namespace BankingApp.Application.Interfaces;

public interface IAuditArchiveRequestService
{
    Task<AuditArchiveJobResponse> QueueAsync(
        AuditArchiveCreateRequest request,
        CancellationToken cancellationToken = default);
}
