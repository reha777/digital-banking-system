using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.AuditLogs;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class AccountService(
        BankingAppDbContext dbContext,
        ICurrentUserService currentUserService,
        IAuditLogService? auditLogService = null) : IAccountService
    {
        public async Task<PagedResult<AccountResponse>> GetAsync(
            AccountQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            IQueryable<Account> query = dbContext.Accounts.AsNoTracking()
                .Include(account => account.AccountTypeDefinition);
            query = ApplyOwnershipFilter(query);

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(account => account.AccountNumber.Contains(search));
            }

            if (request.AccountTypeId.HasValue)
                query = query.Where(account => account.AccountTypeId == request.AccountTypeId.Value);
            if (!string.IsNullOrWhiteSpace(request.AccountTypeCode))
            {
                var code = request.AccountTypeCode.Trim();
                query = query.Where(account => account.AccountTypeDefinition.Code == code);
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
            var accounts = await ApplyOwnershipFilter(
                    dbContext.Accounts.AsNoTracking().Include(account => account.AccountTypeDefinition))
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
            await CloseCoreAsync(account, false, cancellationToken);
            return ToResponse(account);
        }

        public async Task<PagedResult<AdminAccountResponse>> GetAdminAsync(
            AdminAccountQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = AdminQuery();
            if (request.Status.HasValue) query = query.Where(value => value.Status == request.Status);
            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(value => value.AccountNumber.Contains(search) ||
                    value.User.FirstName.Contains(search) || value.User.LastName.Contains(search) ||
                    value.User.Email.Contains(search));
            }
            var total = await query.CountAsync(cancellationToken);
            var entities = await query.OrderByDescending(value => value.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize).Take(request.PageSize)
                .ToListAsync(cancellationToken);
            return new PagedResult<AdminAccountResponse>
            {
                Items = entities.Select(ToAdminResponse).ToList(), Page = request.Page,
                PageSize = request.PageSize, TotalCount = total
            };
        }

        public async Task<AdminAccountResponse> GetAdminByIdAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var account = await AdminQuery().SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
                ?? throw new NotFoundException("Racun nije pronadjen.");
            return ToAdminResponse(account);
        }

        public async Task<AdminAccountResponse> CloseAsAdminAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var account = await AdminQuery(false).SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
                ?? throw new NotFoundException("Racun nije pronadjen.");
            await CloseCoreAsync(account, true, cancellationToken);
            return ToAdminResponse(account);
        }

        private async Task CloseCoreAsync(Account account, bool byAdmin, CancellationToken cancellationToken)
        {
            if (account.Status == AccountStatus.Closed)
                throw new BusinessException("Racun je vec zatvoren.");
            if (account.Balance != 0)
                throw new BusinessException("Samo racun sa stanjem 0.00 moze biti zatvoren.");
            var hasActiveLoan = await dbContext.Loans.AnyAsync(
                loan => loan.DestinationAccountId == account.Id && loan.Status == LoanStatus.Active,
                cancellationToken);
            var hasPendingApplication = await dbContext.LoanApplications.AnyAsync(
                application => application.DestinationAccountId == account.Id &&
                    (application.Status == LoanApplicationStatus.Pending || application.Status == LoanApplicationStatus.DocumentsRequested),
                cancellationToken);
            if (hasActiveLoan || hasPendingApplication)
                throw new BusinessException("Racun sa aktivnim kreditom ili zahtjevom za kredit ne moze biti zatvoren.");
            var card = account.Card ?? await dbContext.BankCards.SingleOrDefaultAsync(value => value.AccountId == account.Id, cancellationToken);
            if (card is not null && card.Status == CardStatus.Active)
                card.Status = CardStatus.Blocked;
            account.Status = AccountStatus.Closed;
            if (byAdmin && auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.AccountClosedByAdmin, EntityType = AuditEntityTypes.Account,
                    EntityId = account.Id.ToString(), Description = $"Closed account {account.AccountNumber}.",
                    OldValue = AccountStatus.Active.ToString(), NewValue = AccountStatus.Closed.ToString()
                }, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        private IQueryable<Account> AdminQuery(bool noTracking = true)
        {
            var query = dbContext.Accounts.Include(value => value.User).Include(value => value.Card)
                .Include(value => value.AccountTypeDefinition).AsQueryable();
            return noTracking ? query.AsNoTracking() : query;
        }

        private static AdminAccountResponse ToAdminResponse(Account account) => new()
        {
            Id = account.Id, CustomerId = account.UserId,
            CustomerName = $"{account.User.FirstName} {account.User.LastName}".Trim(),
            CustomerEmail = account.User.Email, AccountNumber = account.AccountNumber,
            AccountTypeId = account.AccountTypeId, AccountTypeCode = TypeCode(account),
            AccountTypeName = TypeName(account), Status = account.Status, Balance = account.Balance,
            Currency = account.Currency, CreatedAtUtc = account.CreatedAtUtc,
            CardId = account.Card?.Id, CardStatus = account.Card?.Status
        };

        private IQueryable<Account> ApplyOwnershipFilter(IQueryable<Account> query)
        {
            return currentUserService.IsAdmin
                ? query
                : query.Where(account => account.UserId == currentUserService.UserId);
        }

        private async Task<Account> GetOwnedAccountAsync(Guid id, CancellationToken cancellationToken)
        {
            var query = ApplyOwnershipFilter(
                dbContext.Accounts.Include(account => account.AccountTypeDefinition));
            var account = await query.FirstOrDefaultAsync(account => account.Id == id, cancellationToken);

            return account ?? throw new NotFoundException("Racun nije pronadjen.");
        }

        private static AccountResponse ToResponse(Account account)
        {
            return new AccountResponse
            {
                Id = account.Id,
                AccountNumber = account.AccountNumber,
                AccountTypeId = account.AccountTypeId,
                AccountTypeCode = TypeCode(account),
                AccountTypeName = TypeName(account),
                Status = account.Status,
                Balance = account.Balance,
                Currency = account.Currency,
                CreatedAtUtc = account.CreatedAtUtc
            };
        }

        private static string TypeCode(Account account) => account.AccountTypeDefinition?.Code ?? string.Empty;
        private static string TypeName(Account account) => account.AccountTypeDefinition?.Name ?? string.Empty;
    }
}
