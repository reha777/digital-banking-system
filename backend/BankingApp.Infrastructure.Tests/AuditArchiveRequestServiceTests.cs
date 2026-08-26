using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class AuditArchiveRequestServiceTests
{
    [Fact]
    public async Task Admin_request_publishes_bounded_typed_snapshot()
    {
        await using var db = Database();
        var admin = User(AppRoles.Admin);
        db.Users.Add(admin);
        db.AuditLogs.AddRange(
            Audit(admin.Id, DateTime.UtcNow.AddDays(-2)),
            Audit(admin.Id, DateTime.UtcNow));
        await db.SaveChangesAsync();
        var publisher = new CapturingPublisher();
        var service = new AuditArchiveRequestService(
            db, new CurrentUser(admin.Id, true), publisher);

        var result = await service.QueueAsync(new AuditArchiveCreateRequest
        {
            DateFromUtc = DateTime.UtcNow.AddDays(-1)
        });

        Assert.Equal("Queued", result.Status);
        Assert.Equal(1, result.EntryCount);
        Assert.NotNull(publisher.Message);
        Assert.Equal(result.JobId, publisher.Message.JobId);
        Assert.Single(publisher.Message.Entries);
    }

    [Fact]
    public async Task Customer_cannot_publish_archive_job()
    {
        await using var db = Database();
        var customer = User(AppRoles.Customer);
        db.Users.Add(customer);
        await db.SaveChangesAsync();
        var service = new AuditArchiveRequestService(
            db, new CurrentUser(customer.Id, false), new CapturingPublisher());

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            service.QueueAsync(new AuditArchiveCreateRequest()));
    }

    private static BankingAppDbContext Database() => new(
        new DbContextOptionsBuilder<BankingAppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static User User(string role) => new()
    {
        Id = Guid.NewGuid(),
        FirstName = "Test",
        LastName = "User",
        Email = $"{Guid.NewGuid()}@example.com",
        PhoneNumber = "+38761000000",
        PasswordHash = "hash",
        Role = role,
        Status = CustomerStatus.Active,
        CreatedAtUtc = DateTime.UtcNow
    };

    private static AuditLog Audit(Guid actorId, DateTime createdAtUtc) => new()
    {
        Id = Guid.NewGuid(),
        ActorUserId = actorId,
        ActorName = "Desktop Admin",
        ActorRole = AppRoles.Admin,
        Action = "TransactionApproved",
        EntityType = "Transaction",
        EntityId = Guid.NewGuid().ToString(),
        Description = "Transaction approved.",
        CreatedAtUtc = createdAtUtc
    };

    private sealed class CurrentUser(Guid userId, bool isAdmin) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => isAdmin;
    }

    private sealed class CapturingPublisher : IAuditArchivePublisher
    {
        public AuditArchiveRequested? Message { get; private set; }

        public Task PublishAsync(
            AuditArchiveRequested message,
            CancellationToken cancellationToken = default)
        {
            Message = message;
            return Task.CompletedTask;
        }
    }
}
