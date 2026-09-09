using BankingApp.Application.Announcements;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class AnnouncementService(
    BankingAppDbContext db,
    ICurrentUserService currentUser,
    IAuditLogService audit) : IAnnouncementService
{
    public Task<PagedResult<AnnouncementResponse>> GetPublishedAsync(AnnouncementQuery query, CancellationToken token = default) =>
        QueryAsync(db.SystemAnnouncements.AsNoTracking().Where(x => x.PublishAtUtc <= DateTime.UtcNow), query, token);

    public Task<PagedResult<AnnouncementResponse>> GetAdminAsync(AnnouncementQuery query, CancellationToken token = default)
    {
        EnsureAdmin();
        return QueryAsync(db.SystemAnnouncements.AsNoTracking(), query, token);
    }

    public async Task<AnnouncementResponse> GetAdminByIdAsync(Guid id, CancellationToken token = default)
    {
        EnsureAdmin();
        var value = await db.SystemAnnouncements.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, token)
            ?? throw new NotFoundException("Announcement was not found.");
        return Map(value, DateTime.UtcNow);
    }

    public async Task<AnnouncementResponse> CreateAsync(AnnouncementWriteRequest request, CancellationToken token = default)
    {
        EnsureAdmin();
        var (title, message, publishAt) = Validate(request);
        var value = new SystemAnnouncement
        {
            Id = Guid.NewGuid(), Title = title, Message = message, PublishAtUtc = publishAt,
            CreatedAtUtc = DateTime.UtcNow, CreatedByAdminId = currentUser.UserId
        };
        db.SystemAnnouncements.Add(value);
        await audit.RecordAsync(new AuditLogRecordRequest
        {
            Action = AuditLogActions.AnnouncementCreated,
            EntityType = AuditEntityTypes.SystemAnnouncement,
            EntityId = value.Id.ToString(),
            Description = $"System announcement '{title}' was created.",
            NewValue = publishAt.ToString("O")
        }, token);
        await db.SaveChangesAsync(token);
        return Map(value, DateTime.UtcNow);
    }

    public async Task<AnnouncementResponse> UpdateAsync(Guid id, AnnouncementWriteRequest request, CancellationToken token = default)
    {
        EnsureAdmin();
        var value = await db.SystemAnnouncements.SingleOrDefaultAsync(x => x.Id == id, token)
            ?? throw new NotFoundException("Announcement was not found.");
        var (title, message, publishAt) = Validate(request);
        var oldPublishAt = value.PublishAtUtc;
        value.Title = title; value.Message = message; value.PublishAtUtc = publishAt;
        await audit.RecordAsync(new AuditLogRecordRequest
        {
            Action = AuditLogActions.AnnouncementUpdated,
            EntityType = AuditEntityTypes.SystemAnnouncement,
            EntityId = value.Id.ToString(),
            Description = $"System announcement '{title}' was updated.",
            OldValue = oldPublishAt.ToString("O"), NewValue = publishAt.ToString("O")
        }, token);
        await db.SaveChangesAsync(token);
        return Map(value, DateTime.UtcNow);
    }

    private static async Task<PagedResult<AnnouncementResponse>> QueryAsync(IQueryable<SystemAnnouncement> source, AnnouncementQuery request, CancellationToken token)
    {
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            source = source.Where(x => x.Title.Contains(search) || x.Message.Contains(search));
        }
        var total = await source.CountAsync(token);
        var now = DateTime.UtcNow;
        var entities = await source.OrderByDescending(x => x.PublishAtUtc)
            .Skip((request.Page - 1) * request.PageSize).Take(request.PageSize).ToListAsync(token);
        return new PagedResult<AnnouncementResponse>
        {
            Items = entities.Select(x => Map(x, now)).ToList(), Page = request.Page,
            PageSize = request.PageSize, TotalCount = total
        };
    }

    private static (string Title, string Message, DateTime PublishAtUtc) Validate(AnnouncementWriteRequest request)
    {
        var title = request.Title.Trim(); var message = request.Message.Trim();
        if (title.Length == 0) throw new BusinessException("Title is required.");
        if (message.Length == 0) throw new BusinessException("Message is required.");
        if (title.Length > 160) throw new BusinessException("Title cannot exceed 160 characters.");
        if (message.Length > 2000) throw new BusinessException("Message cannot exceed 2000 characters.");
        if (request.PublishAtUtc == default) throw new BusinessException("Publish date is required.");
        var utc = request.PublishAtUtc.Kind == DateTimeKind.Utc ? request.PublishAtUtc : request.PublishAtUtc.ToUniversalTime();
        return (title, message, utc);
    }

    private void EnsureAdmin()
    {
        if (!currentUser.IsAdmin) throw new UnauthorizedAccessException("Admin access is required.");
    }

    private static AnnouncementResponse Map(SystemAnnouncement value, DateTime now) => new()
    {
        Id = value.Id, Title = value.Title, Message = value.Message, PublishAtUtc = value.PublishAtUtc,
        CreatedAtUtc = value.CreatedAtUtc, CreatedByAdminId = value.CreatedByAdminId,
        IsPublished = value.PublishAtUtc <= now
    };
}
