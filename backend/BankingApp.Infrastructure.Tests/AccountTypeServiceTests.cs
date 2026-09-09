using BankingApp.Application.AccountTypes;
using BankingApp.Application.Accounts;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class AccountTypeServiceTests
{
    [Fact]
    public async Task Admin_crud_normalizes_immutable_code_and_supports_lifecycle()
    {
        await using var f = await Fixture.CreateAsync(); var service = f.Service(true);
        var created = await service.CreateAsync(new AccountTypeCreateRequest { Code = " business ", Name = " Business " });
        Assert.Equal("BUSINESS", created.Code); Assert.True(created.IsActive);
        var updated = await service.UpdateAsync(created.Id, new AccountTypeUpdateRequest { Name = "Business Account" });
        Assert.Equal("BUSINESS", updated.Code); Assert.Equal("Business Account", updated.Name);
        Assert.False((await service.SetActiveAsync(created.Id, false)).IsActive);
        Assert.DoesNotContain(await service.GetActiveAsync(), x => x.Id == created.Id);
        Assert.True((await service.SetActiveAsync(created.Id, true)).IsActive);
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new AccountTypeCreateRequest { Code = "business", Name = "Duplicate" }));
    }

    [Theory]
    [InlineData("", "Name")]
    [InlineData("   ", "Name")]
    [InlineData("CODE", "")]
    public async Task Empty_values_are_rejected(string code, string name)
    {
        await using var f = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => f.Service(true).CreateAsync(new AccountTypeCreateRequest { Code = code, Name = name }));
    }

    [Fact]
    public async Task Customer_cannot_admin_mutate_and_inactive_type_preserves_existing_account()
    {
        await using var f = await Fixture.CreateAsync(); var customer = f.Service(false);
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => customer.CreateAsync(new AccountTypeCreateRequest { Code = "X", Name = "X" }));
        var admin = f.Service(true); await admin.SetActiveAsync(AccountTypeCodes.CheckingId, false);
        Assert.Equal(AccountTypeCodes.CheckingId, (await f.Db.Accounts.SingleAsync()).AccountTypeId);
    }

    [Fact]
    public async Task Account_projection_uses_reference_data_and_keeps_historical_name()
    {
        await using var f = await Fixture.CreateAsync(); var admin = f.Service(true);
        var business = await admin.CreateAsync(new AccountTypeCreateRequest { Code = "business", Name = "Business" });
        (await f.Db.Accounts.SingleAsync()).AccountTypeId = business.Id; await f.Db.SaveChangesAsync();
        var accounts = new AccountService(f.Db, new Current(f.Customer, false));

        var created = (await accounts.GetAsync(new AccountQueryRequest())).Items.Single();
        Assert.Equal("BUSINESS", created.AccountTypeCode);
        Assert.Equal("Business", created.AccountTypeName);
        Assert.Equal("Business", created.AccountType);

        await admin.UpdateAsync(business.Id, new AccountTypeUpdateRequest { Name = "Business Account" });
        await admin.SetActiveAsync(business.Id, false);
        f.Db.ChangeTracker.Clear();

        var renamed = (await accounts.GetAsync(new AccountQueryRequest())).Items.Single();
        Assert.Equal("Business Account", renamed.AccountTypeName);
        Assert.Equal(business.Id, renamed.AccountTypeId);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Guid admin, Guid customer) { Db = db; Admin = admin; Customer = customer; }
        public BankingAppDbContext Db { get; } public Guid Admin { get; } public Guid Customer { get; }
        public AccountTypeService Service(bool admin) => new(Db, new Current(admin ? Admin : Customer, admin), new Audit());
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var admin = User("Admin"); var customer = User("Customer");
            db.AccountTypeDefinitions.AddRange(Type(AccountTypeCodes.CheckingId, AccountTypeCodes.Checking, "Checking"), Type(AccountTypeCodes.SavingsId, AccountTypeCodes.Savings, "Savings"));
            db.Users.AddRange(admin, customer); db.Accounts.Add(new Account { Id = Guid.NewGuid(), UserId = customer.Id, AccountNumber = "BA-TEST", AccountTypeId = AccountTypeCodes.CheckingId, Balance = 0, Currency = "USD", CreatedAtUtc = DateTime.UtcNow });
            await db.SaveChangesAsync(); return new Fixture(db, admin.Id, customer.Id);
        }
        private static AccountTypeDefinition Type(Guid id, string code, string name) => new() { Id = id, Code = code, Name = name, IsActive = true, CreatedAtUtc = DateTime.UtcNow };
        private static User User(string role) => new() { Id = Guid.NewGuid(), FirstName = role, LastName = "User", Email = $"{Guid.NewGuid()}@test", PhoneNumber = "1", PasswordHash = "x", Role = role, CreatedAtUtc = DateTime.UtcNow };
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class Current(Guid id, bool admin) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => admin; }
    private sealed class Audit : IAuditLogService { public Task RecordAsync(AuditLogRecordRequest r, CancellationToken t = default) => Task.CompletedTask; public Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest r, CancellationToken t = default) => throw new NotSupportedException(); }
}
