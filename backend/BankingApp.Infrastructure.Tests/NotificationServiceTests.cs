using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class NotificationServiceTests
{
    [Fact]
    public async Task Writer_persists_one_notification_per_admin_and_deduplicates_semantic_event()
    {
        await using var fixture = await Fixture.CreateAsync();
        var writer = new NotificationWriter(fixture.Db);
        var entityId = Guid.NewGuid();
        var value = new NotificationCreate(Guid.Empty, NotificationType.NewLoanApplication, "New loan", "Review required.", NotificationEntityTypes.LoanApplication, entityId);

        await writer.AddForAdminsAsync(value);
        await writer.AddForAdminsAsync(value);
        await fixture.Db.SaveChangesAsync();

        var notifications = await fixture.Db.Notifications.ToListAsync();
        Assert.Equal(2, notifications.Count);
        Assert.All(notifications, item => Assert.Contains(item.UserId, fixture.AdminIds));
    }

    [Fact]
    public async Task List_is_owned_paged_newest_first_and_unread_count_is_server_state()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.Db.Notifications.AddRange(
            Notice(fixture.CustomerId, DateTime.UtcNow.AddMinutes(-2)),
            Notice(fixture.CustomerId, DateTime.UtcNow),
            Notice(fixture.AdminIds[0], DateTime.UtcNow.AddMinutes(1)));
        await fixture.Db.SaveChangesAsync();
        var service = new NotificationService(fixture.Db, new CurrentUser(fixture.CustomerId));

        var result = await service.GetAsync(new NotificationQuery { Page = 1, PageSize = 1 });

        Assert.Single(result.Items);
        Assert.Equal(2, result.TotalCount);
        Assert.Equal(2, await service.GetUnreadCountAsync());
        Assert.Equal(DateTime.UtcNow.Date, result.Items.Single().CreatedAtUtc.Date);
    }

    [Fact]
    public async Task Mark_read_and_mark_all_affect_only_current_user()
    {
        await using var fixture = await Fixture.CreateAsync();
        var first = Notice(fixture.CustomerId, DateTime.UtcNow);
        var second = Notice(fixture.CustomerId, DateTime.UtcNow.AddSeconds(1));
        var foreign = Notice(fixture.AdminIds[0], DateTime.UtcNow);
        fixture.Db.AddRange(first, second, foreign);
        await fixture.Db.SaveChangesAsync();
        var service = new NotificationService(fixture.Db, new CurrentUser(fixture.CustomerId));

        await service.MarkReadAsync(first.Id);
        await service.MarkAllReadAsync();

        Assert.True((await fixture.Db.Notifications.FindAsync(first.Id))!.IsRead);
        Assert.True((await fixture.Db.Notifications.FindAsync(second.Id))!.IsRead);
        Assert.False((await fixture.Db.Notifications.FindAsync(foreign.Id))!.IsRead);
        await Assert.ThrowsAsync<NotFoundException>(() => service.MarkReadAsync(foreign.Id));
    }

    private static Notification Notice(Guid userId, DateTime created) => new()
    {
        Id = Guid.NewGuid(), UserId = userId, Type = NotificationType.CardRequestApproved,
        Title = "Approved", Message = "Your request was approved.", CreatedAtUtc = created
    };

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Guid customerId, Guid[] adminIds) { Db = db; CustomerId = customerId; AdminIds = adminIds; }
        public BankingAppDbContext Db { get; }
        public Guid CustomerId { get; }
        public Guid[] AdminIds { get; }
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var customerId = Guid.NewGuid(); var admins = new[] { Guid.NewGuid(), Guid.NewGuid() };
            db.Users.Add(User(customerId, AppRoles.Customer));
            db.Users.AddRange(admins.Select(id => User(id, AppRoles.Admin)));
            await db.SaveChangesAsync();
            return new Fixture(db, customerId, admins);
        }
        private static User User(Guid id, string role) => new() { Id = id, FirstName = "Test", LastName = "User", Email = $"{id}@test.local", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = role, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => false; }
}
