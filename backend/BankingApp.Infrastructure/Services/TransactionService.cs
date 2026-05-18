using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class TransactionService(
        BankingAppDbContext dbContext,
        ICurrentUserService currentUserService) : ITransactionService
    {
        public async Task<PagedResult<TransactionResponse>> GetAsync(
            TransactionQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.Transactions
                .AsNoTracking()
                .Include(transaction => transaction.Account)
                .AsQueryable();

            query = ApplyOwnershipFilter(query);

            if (request.AccountId.HasValue)
            {
                query = query.Where(transaction => transaction.AccountId == request.AccountId.Value);
            }

            if (request.Status.HasValue)
            {
                query = query.Where(transaction => transaction.Status == request.Status.Value);
            }

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(transaction =>
                    transaction.ReferenceNumber.Contains(search) ||
                    transaction.Description.Contains(search));
            }

            var totalCount = await query.CountAsync(cancellationToken);
            var items = await query
                .OrderByDescending(transaction => transaction.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .Select(transaction => ToResponse(transaction))
                .ToListAsync(cancellationToken);

            return new PagedResult<TransactionResponse>
            {
                Items = items,
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        public async Task<TransactionResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var transaction = await GetOwnedTransactionAsync(id, cancellationToken);
            return ToResponse(transaction);
        }

        public async Task<TransactionResponse> CreateAsync(
            TransactionCreateRequest request,
            CancellationToken cancellationToken = default)
        {
            if (request.Amount == 0)
            {
                throw new BusinessException("Iznos transakcije mora biti razlicit od nule.");
            }

            var account = await GetOwnedAccountAsync(request.AccountId, cancellationToken);
            var transaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                ReferenceNumber = CreateReferenceNumber(),
                Amount = request.Amount,
                Description = request.Description.Trim(),
                Status = TransactionStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.Transactions.Add(transaction);
            await dbContext.SaveChangesAsync(cancellationToken);

            transaction.Account = account;
            return ToResponse(transaction);
        }

        public async Task<TransactionResponse> UpdateAsync(
            Guid id,
            TransactionUpdateRequest request,
            CancellationToken cancellationToken = default)
        {
            var transaction = await GetOwnedTransactionAsync(id, cancellationToken);

            transaction.Description = request.Description.Trim();
            transaction.Status = request.Status;

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToResponse(transaction);
        }

        public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
        {
            var transaction = await GetOwnedTransactionAsync(id, cancellationToken);

            if (transaction.Status != TransactionStatus.Pending)
            {
                throw new BusinessException("Samo transakcije u Pending statusu se mogu obrisati.");
            }

            dbContext.Transactions.Remove(transaction);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        private IQueryable<Transaction> ApplyOwnershipFilter(IQueryable<Transaction> query)
        {
            return currentUserService.IsAdmin
                ? query
                : query.Where(transaction => transaction.Account.UserId == currentUserService.UserId);
        }

        private async Task<Account> GetOwnedAccountAsync(Guid id, CancellationToken cancellationToken)
        {
            var query = currentUserService.IsAdmin
                ? dbContext.Accounts
                : dbContext.Accounts.Where(account => account.UserId == currentUserService.UserId);

            var account = await query.FirstOrDefaultAsync(account => account.Id == id, cancellationToken);
            return account ?? throw new NotFoundException("Racun nije pronadjen.");
        }

        private async Task<Transaction> GetOwnedTransactionAsync(Guid id, CancellationToken cancellationToken)
        {
            var transaction = await ApplyOwnershipFilter(dbContext.Transactions.Include(item => item.Account))
                .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

            return transaction ?? throw new NotFoundException("Transakcija nije pronadjena.");
        }

        private static string CreateReferenceNumber()
        {
            return $"TXN-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..34];
        }

        private static TransactionResponse ToResponse(Transaction transaction)
        {
            return new TransactionResponse
            {
                Id = transaction.Id,
                AccountId = transaction.AccountId,
                AccountNumber = transaction.Account.AccountNumber,
                ReferenceNumber = transaction.ReferenceNumber,
                Amount = transaction.Amount,
                Description = transaction.Description,
                Status = transaction.Status,
                CreatedAtUtc = transaction.CreatedAtUtc
            };
        }
    }
}
