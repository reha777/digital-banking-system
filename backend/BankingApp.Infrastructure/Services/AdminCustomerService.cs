using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Customers;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class AdminCustomerService(BankingAppDbContext dbContext) : IAdminCustomerService
    {
        public async Task<PagedResult<CustomerResponse>> GetAsync(
            CustomerQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = ApplyQuery(request, BaseCustomerQuery());

            var totalCount = await query.CountAsync(cancellationToken);
            var customerEntities = await query
                .OrderByDescending(customer => customer.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToListAsync(cancellationToken);
            var customers = customerEntities.Select(ToResponse).ToList();

            return new PagedResult<CustomerResponse>
            {
                Items = customers,
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        public async Task<CustomerSummaryResponse> GetSummaryAsync(
            CustomerQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = ApplyQuery(request, BaseCustomerQuery());

            return new CustomerSummaryResponse
            {
                TotalCustomers = await query.CountAsync(cancellationToken),
                ActiveCustomers = await query.CountAsync(
                    customer => customer.Status == CustomerStatus.Active,
                    cancellationToken),
                InactiveCustomers = await query.CountAsync(
                    customer => customer.Status == CustomerStatus.Inactive,
                    cancellationToken),
                BlockedCustomers = await query.CountAsync(
                    customer => customer.Status == CustomerStatus.Blocked,
                    cancellationToken)
            };
        }

        public async Task<CustomerResponse> UpdateAsync(
            Guid id,
            CustomerUpdateRequest request,
            CancellationToken cancellationToken = default)
        {
            var customer = await GetCustomerAsync(id, cancellationToken);

            customer.FirstName = request.FirstName.Trim();
            customer.LastName = request.LastName.Trim();
            customer.PhoneNumber = request.PhoneNumber.Trim();

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(customer);
        }

        public async Task<CustomerResponse> UpdateStatusAsync(
            Guid id,
            CustomerStatusUpdateRequest request,
            CancellationToken cancellationToken = default)
        {
            if (!Enum.IsDefined(request.Status))
            {
                throw new BusinessException("Status klijenta nije validan.");
            }

            var customer = await GetCustomerAsync(id, cancellationToken);
            customer.Status = request.Status;

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(customer);
        }

        public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var customer = await GetCustomerAsync(id, cancellationToken);

            customer.IsDeleted = true;
            customer.DeletedAtUtc = DateTime.UtcNow;
            customer.Status = CustomerStatus.Inactive;

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        private IQueryable<User> BaseCustomerQuery()
        {
            return dbContext.Users
                .AsNoTracking()
                .Include(user => user.Accounts)
                .Where(user =>
                    user.Role == AppRoles.Customer &&
                    !user.IsDeleted);
        }

        private IQueryable<User> ApplyQuery(CustomerQueryRequest request, IQueryable<User> query)
        {
            if (request.Status.HasValue)
            {
                query = query.Where(customer => customer.Status == request.Status.Value);
            }

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(customer =>
                    customer.FirstName.Contains(search) ||
                    customer.LastName.Contains(search) ||
                    customer.Email.Contains(search) ||
                    customer.PhoneNumber.Contains(search) ||
                    customer.Accounts.Any(account => account.AccountNumber.Contains(search)));
            }

            return query;
        }

        private async Task<User> GetCustomerAsync(Guid id, CancellationToken cancellationToken)
        {
            var customer = await dbContext.Users
                .Include(user => user.Accounts)
                .FirstOrDefaultAsync(
                    user =>
                        user.Id == id &&
                        user.Role == AppRoles.Customer &&
                        !user.IsDeleted,
                    cancellationToken);

            return customer ?? throw new NotFoundException("Klijent nije pronadjen.");
        }

        private static CustomerResponse ToResponse(User customer)
        {
            return new CustomerResponse
            {
                Id = customer.Id,
                FirstName = customer.FirstName,
                LastName = customer.LastName,
                FullName = $"{customer.FirstName} {customer.LastName}".Trim(),
                Email = customer.Email,
                PhoneNumber = customer.PhoneNumber,
                Status = customer.Status,
                AccountCount = customer.Accounts.Count,
                TotalBalance = customer.Accounts.Sum(account => account.Balance),
                CreatedAtUtc = customer.CreatedAtUtc
            };
        }
    }
}
