using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class AccountService(
        BankingAppDbContext dbContext,
        ICurrentUserService currentUserService) : IAccountService
    {
        public async Task<PagedResult<AccountResponse>> GetAsync(
            AccountQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.Accounts.AsNoTracking();
            query = ApplyOwnershipFilter(query);

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(account => account.AccountNumber.Contains(search));
            }

            if (request.AccountType.HasValue)
            {
                query = query.Where(account => account.AccountType == request.AccountType.Value);
            }

            if (!string.IsNullOrWhiteSpace(request.Currency))
            {
                var currency = request.Currency.Trim().ToUpperInvariant();
                query = query.Where(account => account.Currency == currency);
            }

            var totalCount = await query.CountAsync(cancellationToken);
            var items = await query
                .OrderBy(account => account.AccountNumber)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .Select(account => ToResponse(account))
                .ToListAsync(cancellationToken);

            return new PagedResult<AccountResponse>
            {
                Items = items,
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        public async Task<AccountResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var account = await GetOwnedAccountAsync(id, cancellationToken);
            return ToResponse(account);
        }

        public async Task<AccountResponse> CreateAsync(
            AccountCreateRequest request,
            CancellationToken cancellationToken = default)
        {
            var accountNumber = request.AccountNumber.Trim();
            var accountNumberExists = await dbContext.Accounts
                .AnyAsync(account => account.AccountNumber == accountNumber, cancellationToken);

            if (accountNumberExists)
            {
                throw new BusinessException("Racun sa ovim brojem vec postoji.");
            }

            var account = new Account
            {
                Id = Guid.NewGuid(),
                UserId = currentUserService.UserId,
                AccountNumber = accountNumber,
                AccountType = request.AccountType,
                Balance = request.OpeningBalance,
                Currency = request.Currency.Trim().ToUpperInvariant(),
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.Accounts.Add(account);
            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(account);
        }

        public async Task<AccountResponse> UpdateAsync(
            Guid id,
            AccountUpdateRequest request,
            CancellationToken cancellationToken = default)
        {
            var account = await GetOwnedAccountAsync(id, cancellationToken);
            var accountNumber = request.AccountNumber.Trim();

            var accountNumberExists = await dbContext.Accounts
                .AnyAsync(existingAccount =>
                    existingAccount.Id != id &&
                    existingAccount.AccountNumber == accountNumber,
                    cancellationToken);

            if (accountNumberExists)
            {
                throw new BusinessException("Racun sa ovim brojem vec postoji.");
            }

            account.AccountNumber = accountNumber;
            account.AccountType = request.AccountType;
            account.Currency = request.Currency.Trim().ToUpperInvariant();

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(account);
        }

        public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var account = await GetOwnedAccountAsync(id, cancellationToken);
            var hasTransactions = await dbContext.Transactions
                .AnyAsync(transaction => transaction.AccountId == id, cancellationToken);

            if (hasTransactions)
            {
                throw new BusinessException("Racun nije moguce obrisati jer ima povezane transakcije.");
            }

            dbContext.Accounts.Remove(account);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        private IQueryable<Account> ApplyOwnershipFilter(IQueryable<Account> query)
        {
            return currentUserService.IsAdmin
                ? query
                : query.Where(account => account.UserId == currentUserService.UserId);
        }

        private async Task<Account> GetOwnedAccountAsync(Guid id, CancellationToken cancellationToken)
        {
            var query = ApplyOwnershipFilter(dbContext.Accounts);
            var account = await query.FirstOrDefaultAsync(account => account.Id == id, cancellationToken);

            return account ?? throw new NotFoundException("Racun nije pronadjen.");
        }

        private static AccountResponse ToResponse(Account account)
        {
            return new AccountResponse
            {
                Id = account.Id,
                AccountNumber = account.AccountNumber,
                AccountType = account.AccountType,
                Balance = account.Balance,
                Currency = account.Currency,
                CreatedAtUtc = account.CreatedAtUtc
            };
        }
    }
}
