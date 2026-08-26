using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using BankingApp.Infrastructure.Persistence;

namespace BankingApp.Infrastructure.Services;

public sealed class NotificationWriter(BankingAppDbContext db) : INotificationWriter
{
    public async Task AddAsync(NotificationCreate value, CancellationToken token = default)
    {
        if (value.EntityId.HasValue && !string.IsNullOrWhiteSpace(value.EntityType))
        {
            var tracked = db.Notifications.Local.Any(x => x.UserId == value.UserId && x.Type == value.Type && x.EntityType == value.EntityType && x.EntityId == value.EntityId);
            if (tracked || await db.Notifications.AsNoTracking().AnyAsync(x => x.UserId == value.UserId && x.Type == value.Type && x.EntityType == value.EntityType && x.EntityId == value.EntityId, token)) return;
        }
        db.Notifications.Add(new Notification { Id = Guid.NewGuid(), UserId = value.UserId, Type = value.Type, Title = value.Title, Message = value.Message, EntityType = value.EntityType, EntityId = value.EntityId, CreatedAtUtc = DateTime.UtcNow });
    }
    public async Task AddForAdminsAsync(NotificationCreate value, CancellationToken token = default)
    {
        var admins = await db.Users.AsNoTracking()
            .Where(x => x.Role == AppRoles.Admin && !x.IsDeleted && x.Status == CustomerStatus.Active)
            .Select(x => x.Id)
            .ToListAsync(token);
        foreach (var adminId in admins) await AddAsync(value with { UserId = adminId }, token);
    }
}
