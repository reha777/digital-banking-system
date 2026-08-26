using BankingApp.Application.Messaging;

namespace BankingApp.Application.Interfaces;

public interface IAuditArchivePublisher
{
    Task PublishAsync(
        AuditArchiveRequested message,
        CancellationToken cancellationToken = default);
}
