using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class AuditArchiveRequestService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUser,
    IAuditArchivePublisher publisher) : IAuditArchiveRequestService
{
    private const int MaximumArchiveEntries = 5000;

    public async Task<AuditArchiveJobResponse> QueueAsync(
        AuditArchiveCreateRequest request,
        CancellationToken cancellationToken = default)
    {
        if (!currentUser.IsAdmin)
            throw new UnauthorizedAccessException("Admin access is required.");
        if (request.DateFromUtc.HasValue && request.DateToUtc.HasValue &&
            request.DateFromUtc > request.DateToUtc)
            throw new BusinessException("DateFromUtc ne moze biti nakon DateToUtc.");

        var isAdmin = await dbContext.Users.AsNoTracking().AnyAsync(
            user => user.Id == currentUser.UserId && user.Role == AppRoles.Admin,
            cancellationToken);
        if (!isAdmin) throw new UnauthorizedAccessException("Admin access is required.");

        var query = dbContext.AuditLogs.AsNoTracking();
        if (request.DateFromUtc.HasValue)
            query = query.Where(item => item.CreatedAtUtc >= request.DateFromUtc.Value);
        if (request.DateToUtc.HasValue)
            query = query.Where(item => item.CreatedAtUtc <= request.DateToUtc.Value);

        var entries = await query
            .OrderBy(item => item.CreatedAtUtc)
            .Take(MaximumArchiveEntries + 1)
            .Select(item => new AuditArchiveEntry(
                item.Id, item.ActorUserId, item.ActorName, item.ActorRole,
                item.Action, item.EntityType, item.EntityId, item.Description,
                item.Reason, item.OldValue, item.NewValue, item.CorrelationId,
                item.CreatedAtUtc))
            .ToListAsync(cancellationToken);
        if (entries.Count > MaximumArchiveEntries)
            throw new BusinessException(
                $"Audit archive is limited to {MaximumArchiveEntries} entries. Narrow the date range.");

        var message = new AuditArchiveRequested(
            Guid.NewGuid(), currentUser.UserId, DateTime.UtcNow,
            request.DateFromUtc, request.DateToUtc, entries);
        await publisher.PublishAsync(message, cancellationToken);
        return new AuditArchiveJobResponse(message.JobId, entries.Count, "Queued");
    }
}
