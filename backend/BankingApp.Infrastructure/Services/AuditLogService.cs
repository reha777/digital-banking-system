using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class AuditLogService(BankingAppDbContext dbContext, ICurrentUserService currentUser)
    : IAuditLogService
{
    public async Task RecordAsync(AuditLogRecordRequest request, CancellationToken cancellationToken = default)
    {
        if (!currentUser.IsAdmin) throw new UnauthorizedAccessException("Admin access is required.");
        var actor = await dbContext.Users.AsNoTracking()
            .Where(user => user.Id == currentUser.UserId && user.Role == AppRoles.Admin)
            .Select(user => new { user.FirstName, user.LastName, user.Role })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("Administrator nije pronadjen.");
        dbContext.AuditLogs.Add(new AuditLog
        {
            Id = Guid.NewGuid(),
            ActorUserId = currentUser.UserId,
            ActorName = $"{actor.FirstName} {actor.LastName}".Trim(),
            ActorRole = actor.Role,
            Action = request.Action,
            EntityType = request.EntityType,
            EntityId = request.EntityId,
            Description = request.Description,
            Reason = Clean(request.Reason),
            OldValue = Clean(request.OldValue),
            NewValue = Clean(request.NewValue),
            CorrelationId = Clean(request.CorrelationId),
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    public async Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken cancellationToken = default)
    {
        if (!currentUser.IsAdmin) throw new UnauthorizedAccessException("Admin access is required.");
        var query = dbContext.AuditLogs.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(x => x.ActorName.Contains(search) || x.Action.Contains(search) ||
                x.EntityId.Contains(search) || x.Description.Contains(search));
        }
        if (!string.IsNullOrWhiteSpace(request.Action)) query = query.Where(x => x.Action == request.Action);
        if (!string.IsNullOrWhiteSpace(request.EntityType)) query = query.Where(x => x.EntityType == request.EntityType);
        if (request.DateFrom.HasValue) query = query.Where(x => x.CreatedAtUtc >= request.DateFrom.Value);
        if (request.DateTo.HasValue) query = query.Where(x => x.CreatedAtUtc <= request.DateTo.Value);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(x => x.CreatedAtUtc)
            .Skip((request.Page - 1) * request.PageSize).Take(request.PageSize)
            .Select(x => new AuditLogResponse
            {
                Id = x.Id,
                ActorName = x.ActorName,
                ActorRole = x.ActorRole,
                Action = x.Action,
                ActionDisplayName = Display(x.Action),
                EntityType = x.EntityType,
                EntityId = x.EntityId,
                Description = x.Description,
                Reason = x.Reason,
                OldValue = x.OldValue,
                NewValue = x.NewValue,
                CorrelationId = x.CorrelationId,
                CreatedAtUtc = x.CreatedAtUtc
            }).ToListAsync(cancellationToken);
        return new PagedResult<AuditLogResponse> { Items = items, Page = request.Page, PageSize = request.PageSize, TotalCount = total };
    }

    private static string Display(string value) => string.Concat(value.Select((c, i) => i > 0 && char.IsUpper(c) ? $" {c}" : c.ToString()));
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
