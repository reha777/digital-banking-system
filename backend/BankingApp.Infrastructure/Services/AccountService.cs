using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Enums;
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
                if (!SupportedCurrencies.IsSupported(request.Currency))
                    throw new BusinessException("Valuta nije podrzana. Dozvoljene valute su USD, EUR i BAM.");
                var currency = SupportedCurrencies.Normalize(request.Currency);
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

        public async Task<AccountBalanceSummaryResponse> GetBalanceSummaryAsync(
            CancellationToken cancellationToken = default)
        {
            var accounts = await ApplyOwnershipFilter(dbContext.Accounts.AsNoTracking())
                .Where(account => account.Status == AccountStatus.Active)
                .OrderBy(account => account.AccountNumber)
                .ToListAsync(cancellationToken);

            return new AccountBalanceSummaryResponse
            {
                Totals = accounts
                    .GroupBy(account => account.Currency)
                    .OrderBy(group => group.Key)
                    .Select(group => new CurrencyBalanceResponse
                    {
                        Currency = group.Key,
                        Balance = group.Sum(account => account.Balance)
                    })
                    .ToList(),
                Accounts = accounts.Select(ToResponse).ToList()
            };
        }

        public async Task<AccountResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var account = await GetOwnedAccountAsync(id, cancellationToken);
            return ToResponse(account);
        }

        public async Task<AccountResponse> CloseAsync(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var account = await GetOwnedAccountAsync(id, cancellationToken);
            if (account.Status == AccountStatus.Closed) return ToResponse(account);
            if (account.Balance != 0)
                throw new BusinessException("Samo racun sa stanjem 0.00 moze biti zatvoren.");
            var hasActiveLoan = await dbContext.Loans.AnyAsync(
                loan => loan.DestinationAccountId == id && loan.Status == LoanStatus.Active,
                cancellationToken);
            var hasPendingApplication = await dbContext.LoanApplications.AnyAsync(
                application => application.DestinationAccountId == id &&
                    application.Status == LoanApplicationStatus.Pending,
                cancellationToken);
            if (hasActiveLoan || hasPendingApplication)
                throw new BusinessException("Racun sa aktivnim kreditom ili zahtjevom za kredit ne moze biti zatvoren.");
            var card = await dbContext.BankCards.SingleOrDefaultAsync(
                value => value.AccountId == id,
                cancellationToken);
            if (card is not null && card.Status == CardStatus.Active)
                card.Status = CardStatus.Blocked;
            account.Status = AccountStatus.Closed;
            await dbContext.SaveChangesAsync(cancellationToken);
            return ToResponse(account);
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
                Status = account.Status,
                Balance = account.Balance,
                Currency = account.Currency,
                CreatedAtUtc = account.CreatedAtUtc
            };
        }
    }
}
