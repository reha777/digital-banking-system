using BankingApp.Api.Controllers;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Customers;
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

public class AuditLogServiceTests
{
    [Fact]
    public void Endpoint_is_admin_only()
    {
        var attribute = Assert.Single(typeof(AdminAuditLogsController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, attribute.Roles);
    }

    [Fact]
    public async Task Customer_updates_status_and_delete_create_safe_audit_records()
    {
        await using var fixture = await Fixture.CreateAsync();
        var customerService = new AdminCustomerService(fixture.Db,
            new UserSessionRevocationService(fixture.Db), fixture.Audit);

        await customerService.UpdateAsync(fixture.Customer.Id, new CustomerUpdateRequest
        { FirstName = "Updated", LastName = "Customer", PhoneNumber = "+38761111111" });
        await customerService.UpdateStatusAsync(fixture.Customer.Id,
            new CustomerStatusUpdateRequest { Status = CustomerStatus.Blocked });
        await customerService.DeleteAsync(fixture.Customer.Id);

        var records = await fixture.Audit.GetAsync(new AuditLogQueryRequest { PageSize = 20 });
        Assert.Equal(3, records.TotalCount);
        var status = Assert.Single(records.Items, x => x.Action == AuditLogActions.CustomerStatusChanged);
        Assert.Equal("Active", status.OldValue);
        Assert.Equal("Blocked", status.NewValue);
        Assert.DoesNotContain(records.Items, x => x.Description.Contains("password", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Query_supports_action_entity_date_search_pagination_and_newest_first()
    {
        await using var fixture = await Fixture.CreateAsync();
        foreach (var action in new[] { AuditLogActions.TransactionApproved, AuditLogActions.TransactionRejected,
                     AuditLogActions.TransactionDocumentsRequested, AuditLogActions.CardRequestApproved,
                     AuditLogActions.CardRequestRejected, AuditLogActions.CardDocumentsRequested,
                     AuditLogActions.LoanApproved, AuditLogActions.LoanRejected,
                     AuditLogActions.AdminSettingsUpdated })
        {
            await fixture.Audit.RecordAsync(new AuditLogRecordRequest
            {
                Action = action, EntityType = action.StartsWith("Loan") ? AuditEntityTypes.LoanApplication : AuditEntityTypes.Transaction,
                EntityId = Guid.NewGuid().ToString(), Description = $"Safe {action} record."
            });
            await fixture.Db.SaveChangesAsync();
        }

        var result = await fixture.Audit.GetAsync(new AuditLogQueryRequest
        {
            Page = 1, PageSize = 2, Search = "Safe", Action = AuditLogActions.LoanApproved,
            EntityType = AuditEntityTypes.LoanApplication,
            DateFrom = DateTime.UtcNow.AddMinutes(-1), DateTo = DateTime.UtcNow.AddMinutes(1)
        });
        Assert.Single(result.Items);
        Assert.Equal(AuditLogActions.LoanApproved, result.Items.First().Action);
        var all = await fixture.Audit.GetAsync(new AuditLogQueryRequest { PageSize = 20 });
        Assert.True(all.Items.Zip(all.Items.Skip(1), (a, b) => a.CreatedAtUtc >= b.CreatedAtUtc).All(x => x));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User customer, AuditLogService audit)
        { Db = db; Customer = customer; Audit = audit; }
        public BankingAppDbContext Db { get; }
        public User Customer { get; }
        public AuditLogService Audit { get; }
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var admin = User("Admin", AppRoles.Admin);
            var customer = User("Customer", AppRoles.Customer);
            db.Users.AddRange(admin, customer);
            await db.SaveChangesAsync();
            return new Fixture(db, customer, new AuditLogService(db, new CurrentUser(admin.Id, true)));
        }
        private static User User(string first, string role) => new()
        { Id = Guid.NewGuid(), FirstName = first, LastName = "User", Email = $"{Guid.NewGuid()}@example.com",
          PhoneNumber = "+38761000000", PasswordHash = "hash", Role = role,
          Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService
    { public Guid UserId => id; public bool IsAdmin => admin; }
}
