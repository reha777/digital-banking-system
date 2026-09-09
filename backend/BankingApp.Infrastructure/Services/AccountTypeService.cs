using BankingApp.Application.AccountTypes;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class AccountTypeService(BankingAppDbContext db, ICurrentUserService currentUser, IAuditLogService audit) : IAccountTypeService
{
    public async Task<IReadOnlyList<AccountTypeResponse>> GetActiveAsync(CancellationToken token = default) =>
        await db.AccountTypeDefinitions.AsNoTracking().Where(x => x.IsActive).OrderBy(x => x.Name).Select(x => Map(x)).ToListAsync(token);
    public async Task<IReadOnlyList<AccountTypeResponse>> GetAdminAsync(CancellationToken token = default)
    { EnsureAdmin(); return await db.AccountTypeDefinitions.AsNoTracking().OrderBy(x => x.Code).Select(x => Map(x)).ToListAsync(token); }
    public async Task<AccountTypeResponse> GetAdminByIdAsync(Guid id, CancellationToken token = default)
    { EnsureAdmin(); return Map(await FindAsync(id, token)); }
    public async Task<AccountTypeResponse> CreateAsync(AccountTypeCreateRequest request, CancellationToken token = default)
    {
        EnsureAdmin(); var code = NormalizeCode(request.Code); var name = NormalizeName(request.Name);
        if (await db.AccountTypeDefinitions.AnyAsync(x => x.Code == code, token)) throw new BusinessException("Account type code already exists.");
        var value = new AccountTypeDefinition { Id = Guid.NewGuid(), Code = code, Name = name, IsActive = true, CreatedAtUtc = DateTime.UtcNow };
        db.Add(value); await AuditAsync(AuditLogActions.AccountTypeCreated, value, token); await db.SaveChangesAsync(token); return Map(value);
    }
    public async Task<AccountTypeResponse> UpdateAsync(Guid id, AccountTypeUpdateRequest request, CancellationToken token = default)
    {
        EnsureAdmin(); var value = await FindAsync(id, token); value.Name = NormalizeName(request.Name); value.UpdatedAtUtc = DateTime.UtcNow;
        await AuditAsync(AuditLogActions.AccountTypeUpdated, value, token); await db.SaveChangesAsync(token); return Map(value);
    }
    public async Task<AccountTypeResponse> SetActiveAsync(Guid id, bool active, CancellationToken token = default)
    {
        EnsureAdmin(); var value = await FindAsync(id, token); value.IsActive = active; value.UpdatedAtUtc = DateTime.UtcNow;
        await AuditAsync(active ? AuditLogActions.AccountTypeActivated : AuditLogActions.AccountTypeDeactivated, value, token); await db.SaveChangesAsync(token); return Map(value);
    }
    private async Task<AccountTypeDefinition> FindAsync(Guid id, CancellationToken token) =>
        await db.AccountTypeDefinitions.SingleOrDefaultAsync(x => x.Id == id, token) ??
        throw new NotFoundException("Account type was not found.");
    private async Task AuditAsync(string action, AccountTypeDefinition value, CancellationToken token) => await audit.RecordAsync(new AuditLogRecordRequest { Action = action, EntityType = AuditEntityTypes.AccountTypeDefinition, EntityId = value.Id.ToString(), Description = $"Account type {value.Code} was changed.", NewValue = value.Name }, token);
    private void EnsureAdmin() { if (!currentUser.IsAdmin) throw new UnauthorizedAccessException("Admin access is required."); }
    private static string NormalizeCode(string value) { var code = value.Trim().ToUpperInvariant(); if (code.Length == 0) throw new BusinessException("Code is required."); if (code.Length > 40 || code.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '_')) throw new BusinessException("Code may contain only letters, numbers and underscore."); return code; }
    private static string NormalizeName(string value) { var name = value.Trim(); if (name.Length == 0) throw new BusinessException("Name is required."); if (name.Length > 100) throw new BusinessException("Name cannot exceed 100 characters."); return name; }
    private static AccountTypeResponse Map(AccountTypeDefinition x) => new() { Id = x.Id, Code = x.Code, Name = x.Name, IsActive = x.IsActive, CreatedAtUtc = x.CreatedAtUtc, UpdatedAtUtc = x.UpdatedAtUtc };
}
