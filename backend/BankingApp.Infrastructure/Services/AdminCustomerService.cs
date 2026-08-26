using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Common.Models;
using BankingApp.Application.Customers;
using BankingApp.Application.Interfaces;
using BankingApp.Application.AuditLogs;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class AdminCustomerService(
        BankingAppDbContext dbContext,
        IUserSessionRevocationService sessionRevocationService,
        IAuditLogService? auditLogService = null) : IAdminCustomerService
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

        public async Task<AdminCustomerDetailsResponse> GetDetailsAsync(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var customer = await dbContext.Users
                .AsNoTracking()
                .AsSplitQuery()
                .Include(user => user.Accounts)
                .ThenInclude(account => account.Card)
                .SingleOrDefaultAsync(user =>
                    user.Id == id && user.Role == AppRoles.Customer && !user.IsDeleted,
                    cancellationToken)
                ?? throw new NotFoundException("Klijent nije pronadjen.");

            var pendingCardRequests = await dbContext.CardRequests.CountAsync(
                value => value.UserId == id &&
                    (value.Status == CardRequestStatus.Pending ||
                     value.Status == CardRequestStatus.DocumentsRequested),
                cancellationToken);
            var pendingReviews = await dbContext.Transactions.CountAsync(
                value => value.Account.UserId == id && value.IsHighRiskReview &&
                    (value.Status == TransactionStatus.Pending ||
                     value.Status == TransactionStatus.DocumentsRequested),
                cancellationToken);
            var activeLoans = await dbContext.Loans.CountAsync(
                value => value.UserId == id && value.Status == LoanStatus.Active,
                cancellationToken);
            var pendingLoanApplications = await dbContext.LoanApplications.CountAsync(
                value => value.UserId == id && value.Status == LoanApplicationStatus.Pending,
                cancellationToken);

            return new AdminCustomerDetailsResponse
            {
                Id = customer.Id,
                FirstName = customer.FirstName,
                LastName = customer.LastName,
                FullName = $"{customer.FirstName} {customer.LastName}".Trim(),
                Email = customer.Email,
                PhoneNumber = customer.PhoneNumber,
                Status = customer.Status,
                CreatedAtUtc = customer.CreatedAtUtc,
                Balances = customer.Accounts.GroupBy(account => account.Currency)
                    .OrderBy(group => group.Key)
                    .Select(group => new CurrencyAmountResponse
                    {
                        Currency = group.Key,
                        Amount = group.Sum(account => account.Balance)
                    }).ToList(),
                Accounts = customer.Accounts.OrderBy(account => account.AccountNumber)
                    .Select(account => new AdminCustomerAccountResponse
                    {
                        Id = account.Id,
                        AccountNumber = account.AccountNumber,
                        AccountType = account.AccountType,
                        Balance = account.Balance,
                        Currency = account.Currency,
                        CreatedAtUtc = account.CreatedAtUtc,
                        Card = account.Card == null ? null : new AdminCustomerCardResponse
                        {
                            Id = account.Card.Id,
                            MaskedCardNumber = MaskCard(account.Card.CardNumber),
                            CardholderName = account.Card.CardholderName,
                            ExpiryDate = account.Card.ExpiryDate,
                            Brand = account.Card.Brand,
                            Status = account.Card.Status,
                            CreatedAtUtc = account.Card.CreatedAtUtc
                        }
                    }).ToList(),
                Summary = new AdminCustomerRelationshipSummaryResponse
                {
                    AccountCount = customer.Accounts.Count,
                    CardCount = customer.Accounts.Count(account => account.Card != null),
                    ActiveLoanCount = activeLoans,
                    PendingCardRequestCount = pendingCardRequests,
                    PendingTransactionReviewCount = pendingReviews,
                    PendingLoanApplicationCount = pendingLoanApplications
                }
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

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CustomerUpdated,
                    EntityType = AuditEntityTypes.Customer,
                    EntityId = id.ToString(),
                    Description = "Customer basic data updated."
                }, cancellationToken);

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
            var oldStatus = customer.Status;
            customer.Status = request.Status;

            if (request.Status != CustomerStatus.Active)
            {
                await sessionRevocationService.RevokeAllRefreshTokensAsync(id, cancellationToken);
            }

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CustomerStatusChanged,
                    EntityType = AuditEntityTypes.Customer,
                    EntityId = id.ToString(),
                    Description = $"Customer status changed from {oldStatus} to {request.Status}.",
                    OldValue = oldStatus.ToString(),
                    NewValue = request.Status.ToString()
                }, cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(customer);
        }

        public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var customer = await GetCustomerAsync(id, cancellationToken);

            customer.IsDeleted = true;
            customer.DeletedAtUtc = DateTime.UtcNow;
            customer.Status = CustomerStatus.Inactive;

            await sessionRevocationService.RevokeAllRefreshTokensAsync(id, cancellationToken);
            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CustomerDeleted,
                    EntityType = AuditEntityTypes.Customer,
                    EntityId = id.ToString(),
                    Description = "Customer was soft-deleted."
                }, cancellationToken);

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
                Balances = customer.Accounts
                    .GroupBy(account => account.Currency)
                    .OrderBy(group => group.Key)
                    .Select(group => new CurrencyAmountResponse
                    {
                        Currency = group.Key,
                        Amount = group.Sum(account => account.Balance)
                    })
                    .ToList(),
                CreatedAtUtc = customer.CreatedAtUtc
            };
        }

        private static string MaskCard(string value)
        {
            var digits = new string(value.Where(char.IsDigit).ToArray());
            var ending = digits.Length <= 4 ? digits.PadLeft(4, '0') : digits[^4..];
            return $"**** **** **** {ending}";
        }
    }
}
