using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.ReferenceData;
using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class ReferenceDataService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUser,
    IAuditLogService auditLogService) : IReferenceDataService
{
    public async Task<PagedResult<ReferenceDataResponse>> GetAsync(string type, ReferenceDataQuery query, bool activeOnly, CancellationToken cancellationToken = default)
    {
        type = ValidType(type);
        var values = dbContext.ReferenceDataItems.AsNoTracking().Where(value => value.Type == type);
        if (activeOnly) values = values.Where(value => value.IsActive);
        else if (query.IsActive.HasValue) values = values.Where(value => value.IsActive == query.IsActive.Value);
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            values = values.Where(value => value.Code.Contains(search) || value.Name.Contains(search));
        }
        var total = await values.CountAsync(cancellationToken);
        var items = await values.OrderBy(value => value.SortOrder)
            .ThenBy(value => value.Name).ThenBy(value => value.Code).ThenBy(value => value.Id)
            .Skip((query.Page - 1) * query.PageSize).Take(query.PageSize)
            .Select(value => Map(value)).ToListAsync(cancellationToken);
        return new PagedResult<ReferenceDataResponse>
        {
            Items = items,
            Page = query.Page,
            PageSize = query.PageSize,
            TotalCount = total
        };
    }

    public async Task<ReferenceDataResponse> CreateAsync(string type, ReferenceDataWriteRequest request, CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        type = ValidType(type);
        var data = Clean(request);
        await EnsureUniqueAsync(type, data.Code, null, cancellationToken);
        var now = DateTime.UtcNow;
        var entity = new ReferenceDataItem { Id = Guid.NewGuid(), Type = type, Code = data.Code, Name = data.Name, Description = data.Description, IsActive = data.IsActive, SortOrder = data.SortOrder, CreatedAtUtc = now, UpdatedAtUtc = now };
        dbContext.ReferenceDataItems.Add(entity);
        await auditLogService.RecordAsync(new AuditLogRecordRequest { Action = "ReferenceCreated", EntityType = type, EntityId = entity.Id.ToString(), Description = $"Created reference {entity.Code}." }, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Map(entity);
    }

    public async Task<ReferenceDataResponse> UpdateAsync(string type, Guid id, ReferenceDataWriteRequest request, CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        type = ValidType(type);
        var entity = await FindAsync(type, id, cancellationToken);
        var data = Clean(request);
        await EnsureUniqueAsync(type, data.Code, id, cancellationToken);
        entity.Code = data.Code; entity.Name = data.Name; entity.Description = data.Description;
        entity.IsActive = data.IsActive; entity.SortOrder = data.SortOrder; entity.UpdatedAtUtc = DateTime.UtcNow;
        await auditLogService.RecordAsync(new AuditLogRecordRequest { Action = "ReferenceUpdated", EntityType = type, EntityId = id.ToString(), Description = $"Updated reference {entity.Code}." }, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Map(entity);
    }

    public async Task<ReferenceDataResponse> SetActiveAsync(string type, Guid id, bool isActive, CancellationToken cancellationToken = default)
    {
        EnsureAdmin(); type = ValidType(type);
        var entity = await FindAsync(type, id, cancellationToken);
        entity.IsActive = isActive; entity.UpdatedAtUtc = DateTime.UtcNow;
        await auditLogService.RecordAsync(new AuditLogRecordRequest { Action = isActive ? "ReferenceActivated" : "ReferenceDeactivated", EntityType = type, EntityId = id.ToString(), Description = $"{(isActive ? "Activated" : "Deactivated")} reference {entity.Code}." }, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Map(entity);
    }

    private void EnsureAdmin() { if (!currentUser.IsAdmin) throw new UnauthorizedAccessException("Admin access is required."); }
    private static string ValidType(string type) => ReferenceDataTypes.All.Contains(type) ? type.ToLowerInvariant() : throw new NotFoundException("Reference data type was not found.");
    private static ReferenceDataWriteRequest Clean(ReferenceDataWriteRequest value)
    {
        var code = value.Code.Trim().ToUpperInvariant(); var name = value.Name.Trim(); var description = value.Description?.Trim();
        if (code.Length is < 1 or > 40 || name.Length is < 1 or > 120 || description?.Length > 500 || value.SortOrder is < 0 or > 10000)
            throw new BusinessException("Reference data values are invalid.");
        return new ReferenceDataWriteRequest { Code = code, Name = name, Description = string.IsNullOrEmpty(description) ? null : description, IsActive = value.IsActive, SortOrder = value.SortOrder };
    }
    private async Task EnsureUniqueAsync(string type, string code, Guid? exceptId, CancellationToken token)
    { if (await dbContext.ReferenceDataItems.AnyAsync(value => value.Type == type && value.Code == code && value.Id != exceptId, token)) throw new BusinessException("Reference code already exists."); }
    private async Task<ReferenceDataItem> FindAsync(string type, Guid id, CancellationToken token) => await dbContext.ReferenceDataItems.SingleOrDefaultAsync(value => value.Type == type && value.Id == id, token) ?? throw new NotFoundException("Reference value was not found.");
    private static ReferenceDataResponse Map(ReferenceDataItem value) => new() { Id = value.Id, Type = value.Type, Code = value.Code, Name = value.Name, Description = value.Description, IsActive = value.IsActive, SortOrder = value.SortOrder };
}
