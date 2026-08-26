using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.ReferenceData;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class ReferenceDataTests
{
    [Fact]
    public async Task Admin_reference_search_and_status_filters_are_server_paged()
    {
        await using var fixture = await Fixture.CreateAsync(true);
        await fixture.Service.CreateAsync(ReferenceDataTypes.LoanPurposes, Request("ONE", "Match one", 1));
        var second = await fixture.Service.CreateAsync(ReferenceDataTypes.LoanPurposes, Request("TWO", "Match two", 2));
        await fixture.Service.SetActiveAsync(ReferenceDataTypes.LoanPurposes, second.Id, false);

        var active = await fixture.Service.GetAsync(
            ReferenceDataTypes.LoanPurposes,
            new ReferenceDataQuery { Search = "Match", IsActive = true, PageSize = 1 },
            false);
        var inactive = await fixture.Service.GetAsync(
            ReferenceDataTypes.LoanPurposes,
            new ReferenceDataQuery { Search = "Match", IsActive = false, PageSize = 1000 },
            false);

        Assert.Single(active.Items);
        Assert.Equal(1, active.TotalCount);
        Assert.Single(inactive.Items);
        Assert.Equal("TWO", inactive.Items.Single().Code);
        Assert.Equal(100, inactive.PageSize);
    }

    [Theory]
    [InlineData(ReferenceDataTypes.LoanPurposes)]
    [InlineData(ReferenceDataTypes.DocumentTypes)]
    [InlineData(ReferenceDataTypes.TransactionCategories)]
    public async Task Admin_can_create_update_search_and_deactivate_with_audit(string type)
    {
        await using var fixture = await Fixture.CreateAsync(true);
        var created = await fixture.Service.CreateAsync(type, Request(" demo ", "Demo value", 20));
        var updated = await fixture.Service.UpdateAsync(type, created.Id, Request("DEMO", "Updated value", 5));
        await fixture.Service.SetActiveAsync(type, created.Id, false);

        var search = await fixture.Service.GetAsync(type, new ReferenceDataQuery { Search = "Updated", IsActive = false }, false);
        var customer = await fixture.Service.GetAsync(type, new ReferenceDataQuery(), true);

        Assert.Equal("DEMO", updated.Code);
        Assert.Single(search.Items);
        Assert.DoesNotContain(customer.Items, value => value.Id == created.Id);
        Assert.Equal(3, await fixture.Db.AuditLogs.CountAsync());
    }

    [Fact]
    public async Task Codes_are_case_insensitively_unique_and_non_admin_cannot_mutate()
    {
        await using var admin = await Fixture.CreateAsync(true);
        await admin.Service.CreateAsync(ReferenceDataTypes.LoanPurposes, Request("HOME", "Home", 1));
        await Assert.ThrowsAsync<BusinessException>(() => admin.Service.CreateAsync(
            ReferenceDataTypes.LoanPurposes, Request("home", "Duplicate", 2)));

        await using var customer = await Fixture.CreateAsync(false);
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => customer.Service.CreateAsync(
            ReferenceDataTypes.DocumentTypes, Request("ID", "Identity", 1)));
    }

    private static ReferenceDataWriteRequest Request(string code, string name, int sort) => new()
    { Code = code, Name = name, IsActive = true, SortOrder = sort };

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, ReferenceDataService service) { Db = db; Service = service; }
        public BankingAppDbContext Db { get; }
        public ReferenceDataService Service { get; }
        public static async Task<Fixture> CreateAsync(bool admin)
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var user = new User { Id = Guid.NewGuid(), FirstName = "Test", LastName = "User", Email = $"{Guid.NewGuid()}@test.local", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = admin ? AppRoles.Admin : AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            db.Users.Add(user); await db.SaveChangesAsync();
            var current = new CurrentUser(user.Id, admin);
            var audit = new AuditLogService(db, current);
            return new Fixture(db, new ReferenceDataService(db, current, audit));
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService
    { public Guid UserId => id; public bool IsAdmin => admin; }
}
