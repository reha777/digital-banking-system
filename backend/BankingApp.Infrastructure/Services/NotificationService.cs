using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class NotificationService(BankingAppDbContext db, ICurrentUserService currentUser) : INotificationService
{
    public async Task<PagedResult<NotificationResponse>> GetAsync(NotificationQuery request, CancellationToken token = default)
    {
        var query = db.Notifications.AsNoTracking().Where(x => x.UserId == currentUser.UserId);
        if (request.UnreadOnly) query = query.Where(x => !x.IsRead);
        var total = await query.CountAsync(token);
        var entities = await query.OrderByDescending(x => x.CreatedAtUtc).Skip((request.Page - 1) * request.PageSize).Take(request.PageSize).ToListAsync(token);
        var items = entities.Select(Map).ToList();
        return new PagedResult<NotificationResponse> { Items = items, Page = request.Page, PageSize = request.PageSize, TotalCount = total };
    }
    public Task<int> GetUnreadCountAsync(CancellationToken token = default) => db.Notifications.CountAsync(x => x.UserId == currentUser.UserId && !x.IsRead, token);
    public async Task MarkReadAsync(Guid id, CancellationToken token = default)
    {
        var value = await db.Notifications.SingleOrDefaultAsync(x => x.Id == id && x.UserId == currentUser.UserId, token) ?? throw new NotFoundException("Notification was not found.");
        if (!value.IsRead) { value.IsRead = true; value.ReadAtUtc = DateTime.UtcNow; await db.SaveChangesAsync(token); }
    }
    public async Task MarkAllReadAsync(CancellationToken token = default)
    {
        var now = DateTime.UtcNow;
        if (db.Database.IsRelational())
        {
            await db.Notifications.Where(x => x.UserId == currentUser.UserId && !x.IsRead).ExecuteUpdateAsync(setters => setters.SetProperty(x => x.IsRead, true).SetProperty(x => x.ReadAtUtc, now), token);
            return;
        }
        var values = await db.Notifications.Where(x => x.UserId == currentUser.UserId && !x.IsRead).ToListAsync(token);
        foreach (var value in values) { value.IsRead = true; value.ReadAtUtc = now; }
        await db.SaveChangesAsync(token);
    }
    private static NotificationResponse Map(Notification x) => new() { Id = x.Id, Type = x.Type.ToString(), Title = x.Title, Message = x.Message, EntityType = x.EntityType, EntityId = x.EntityId, IsRead = x.IsRead, CreatedAtUtc = x.CreatedAtUtc, ReadAtUtc = x.ReadAtUtc };
}
