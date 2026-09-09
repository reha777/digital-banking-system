using BankingApp.Api.Controllers;
using BankingApp.Application.Announcements;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class AnnouncementServiceTests
{
    [Fact]
    public async Task Admin_creates_trimmed_announcement_with_server_actor_and_audit()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.AdminId, true);
        var result = await service.CreateAsync(new AnnouncementWriteRequest
        {
            Title = "  Scheduled maintenance  ", Message = "  Service window.  ", PublishAtUtc = DateTime.UtcNow
        });
        var stored = await fixture.Db.SystemAnnouncements.SingleAsync();
        Assert.Equal("Scheduled maintenance", stored.Title);
        Assert.Equal(fixture.AdminId, stored.CreatedByAdminId);
        Assert.NotEqual(default, stored.CreatedAtUtc);
        Assert.True(result.IsPublished);
        Assert.Equal(AuditLogActions.AnnouncementCreated, Assert.Single(fixture.Audit.Records).Action);
    }

    [Fact]
    public async Task Published_query_hides_scheduled_but_admin_query_returns_both()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.AdminId, true);
        await service.CreateAsync(Request("Published", DateTime.UtcNow.AddMinutes(-1)));
        await service.CreateAsync(Request("Scheduled", DateTime.UtcNow.AddHours(1)));
        var customer = fixture.Service(fixture.CustomerId, false);
        var published = await customer.GetPublishedAsync(new AnnouncementQuery());
        var all = await service.GetAdminAsync(new AnnouncementQuery());
        Assert.Single(published.Items);
        Assert.Equal("Published", published.Items.Single().Title);
        Assert.Equal(2, all.TotalCount);
    }

    [Fact]
    public async Task Publish_time_is_normalized_to_utc_once_and_scheduling_still_compares_in_utc()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.AdminId, true);
        var instant = DateTime.UtcNow.AddHours(1);

        // A non-UTC kind is converted once, so the instant is preserved rather than shifted twice.
        var scheduled = await service.CreateAsync(Request("Scheduled", instant.ToLocalTime()));
        var stored = await fixture.Db.SystemAnnouncements.SingleAsync();
        Assert.Equal(DateTimeKind.Utc, stored.PublishAtUtc.Kind);
        Assert.Equal(instant, stored.PublishAtUtc, TimeSpan.FromSeconds(1));
        Assert.False(scheduled.IsPublished);

        // An already-UTC value is left exactly as sent.
        await service.UpdateAsync(stored.Id, Request("Scheduled", instant));
        Assert.Equal(instant, (await fixture.Db.SystemAnnouncements.SingleAsync()).PublishAtUtc, TimeSpan.FromSeconds(1));

        // The published/scheduled comparison keeps working off UTC.
        await service.UpdateAsync(stored.Id, Request("Scheduled", DateTime.UtcNow.AddMinutes(-1)));
        var published = await fixture.Service(fixture.CustomerId, false).GetPublishedAsync(new AnnouncementQuery());
        Assert.True(Assert.Single(published.Items).IsPublished);
    }

    [Fact]
    public async Task Customer_cannot_create_update_or_use_admin_read()
    {
        await using var fixture = await Fixture.CreateAsync();
        var customer = fixture.Service(fixture.CustomerId, false);
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => customer.CreateAsync(Request("Title", DateTime.UtcNow)));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => customer.GetAdminAsync(new AnnouncementQuery()));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => customer.UpdateAsync(Guid.NewGuid(), Request("Title", DateTime.UtcNow)));
    }

    [Theory]
    [InlineData("", "Message")]
    [InlineData("   ", "Message")]
    [InlineData("Title", "")]
    [InlineData("Title", "   ")]
    public async Task Empty_or_whitespace_content_is_rejected(string title, string message)
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service(fixture.AdminId, true).CreateAsync(new AnnouncementWriteRequest
        { Title = title, Message = message, PublishAtUtc = DateTime.UtcNow }));
    }

    [Fact]
    public void Controllers_have_separate_customer_and_admin_authorization()
    {
        var customer = Assert.Single(typeof(AnnouncementsController).GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        var admin = Assert.Single(typeof(AdminAnnouncementsController).GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Customer, customer.Roles);
        Assert.Equal(AppRoles.Admin, admin.Roles);
    }

    private static AnnouncementWriteRequest Request(string title, DateTime publishAt) => new() { Title = title, Message = "Important information.", PublishAtUtc = publishAt };

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Guid adminId, Guid customerId) { Db = db; AdminId = adminId; CustomerId = customerId; }
        public BankingAppDbContext Db { get; }
        public Guid AdminId { get; }
        public Guid CustomerId { get; }
        public CapturingAudit Audit { get; } = new();
        public AnnouncementService Service(Guid id, bool admin) => new(Db, new CurrentUser(id, admin), Audit);
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var admin = User(AppRoles.Admin); var customer = User(AppRoles.Customer);
            db.Users.AddRange(admin, customer); await db.SaveChangesAsync();
            return new Fixture(db, admin.Id, customer.Id);
        }
        private static User User(string role) => new() { Id = Guid.NewGuid(), FirstName = "Test", LastName = role, Email = $"{Guid.NewGuid()}@test.local", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = role, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => admin; }
    private sealed class CapturingAudit : IAuditLogService
    {
        public List<AuditLogRecordRequest> Records { get; } = [];
        public Task RecordAsync(AuditLogRecordRequest request, CancellationToken token = default) { Records.Add(request); return Task.CompletedTask; }
        public Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken token = default) => throw new NotSupportedException();
    }
}
