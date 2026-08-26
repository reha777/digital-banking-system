using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class CustomerAccessValidator(BankingAppDbContext dbContext)
    : ICustomerAccessValidator
{
    public Task<bool> IsActiveCustomerAsync(
        Guid userId,
        CancellationToken cancellationToken = default) =>
        dbContext.Users.AsNoTracking().AnyAsync(
            user =>
                user.Id == userId &&
                user.Role == AppRoles.Customer &&
                !user.IsDeleted &&
                user.Status == CustomerStatus.Active,
            cancellationToken);
}
