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

            query = ApplyQuery(request, query);

            var totalCount = await query.CountAsync(cancellationToken);
            var transactions = await query
                .OrderByDescending(transaction => transaction.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToListAsync(cancellationToken);
            var items = transactions.Select(ToResponse).ToList();
            await PopulateTransferDetailsAsync(items, cancellationToken);

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
            var response = ToResponse(transaction);
            await PopulateTransferDetailsAsync([response], cancellationToken);
            return response;
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

        public async Task<MoneyTransferResponse> SendMoneyAsync(
            MoneyTransferRequest request,
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
            {
                throw new BusinessException("Admin korisnik ne moze slati novac u ime klijenta.");
            }

            if (request.Amount <= 0)
            {
                throw new BusinessException("Iznos za slanje mora biti veci od nule.");
            }

            var destinationAccountNumber = request.DestinationAccountNumber.Trim();
            if (string.IsNullOrWhiteSpace(destinationAccountNumber))
            {
                throw new BusinessException("Racun primaoca je obavezan.");
            }

            var sourceAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(
                    account =>
                        account.Id == request.SourceAccountId &&
                        account.UserId == currentUserService.UserId,
                    cancellationToken);

            if (sourceAccount is null)
            {
                throw new NotFoundException("Racun sa kojeg saljete novac nije pronadjen.");
            }

            var destinationAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(
                    account => account.AccountNumber == destinationAccountNumber,
                    cancellationToken);

            if (destinationAccount is null)
            {
                throw new NotFoundException("Racun primaoca nije pronadjen.");
            }

            if (sourceAccount.Id == destinationAccount.Id)
            {
                throw new BusinessException("Novac nije moguce poslati na isti racun.");
            }

            if (sourceAccount.UserId == destinationAccount.UserId)
            {
                throw new BusinessException("Novac nije moguce poslati samom sebi.");
            }

            if (sourceAccount.Currency != destinationAccount.Currency)
            {
                throw new BusinessException("Transfer je moguc samo izmedju racuna iste valute.");
            }

            if (sourceAccount.Balance < request.Amount)
            {
                throw new BusinessException("Nedovoljno sredstava na racunu.");
            }

            var referenceNumber = CreateReferenceNumber();
            var createdAtUtc = DateTime.UtcNow;
            var description = string.IsNullOrWhiteSpace(request.Description)
                ? $"Transfer to {destinationAccount.AccountNumber}"
                : request.Description.Trim();

            sourceAccount.Balance -= request.Amount;
            destinationAccount.Balance += request.Amount;

            var debitTransaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = sourceAccount.Id,
                SourceAccountId = sourceAccount.Id,
                DestinationAccountId = destinationAccount.Id,
                ReferenceNumber = referenceNumber,
                Amount = -request.Amount,
                Description = description,
                Status = TransactionStatus.Completed,
                CreatedAtUtc = createdAtUtc
            };

            var creditTransaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = destinationAccount.Id,
                SourceAccountId = sourceAccount.Id,
                DestinationAccountId = destinationAccount.Id,
                ReferenceNumber = referenceNumber,
                Amount = request.Amount,
                Description = $"Transfer from {sourceAccount.AccountNumber}",
                Status = TransactionStatus.Completed,
                CreatedAtUtc = createdAtUtc
            };

            dbContext.Transactions.AddRange(debitTransaction, creditTransaction);
            await dbContext.SaveChangesAsync(cancellationToken);

            debitTransaction.Account = sourceAccount;
            creditTransaction.Account = destinationAccount;

            return new MoneyTransferResponse
            {
                ReferenceNumber = referenceNumber,
                Status = TransactionStatus.Completed,
                Amount = request.Amount,
                Currency = sourceAccount.Currency,
                SourceAccount = ToTransferAccountResponse(sourceAccount),
                DestinationAccount = ToTransferAccountResponse(destinationAccount),
                DebitTransaction = ToResponse(debitTransaction, sourceAccount, destinationAccount),
                CreditTransaction = ToResponse(creditTransaction, sourceAccount, destinationAccount),
                CreatedAtUtc = createdAtUtc
            };
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

        private IQueryable<Transaction> ApplyQuery(
            TransactionQueryRequest request,
            IQueryable<Transaction> query)
        {
            query = ApplyOwnershipFilter(query);

            if (currentUserService.IsAdmin)
            {
                query = query.Where(transaction =>
                    !transaction.SourceAccountId.HasValue ||
                    transaction.AccountId == transaction.SourceAccountId.Value);
            }

            if (request.AccountId.HasValue)
            {
                query = query.Where(transaction => transaction.AccountId == request.AccountId.Value);
            }

            if (request.Status.HasValue)
            {
                query = query.Where(transaction => transaction.Status == request.Status.Value);
            }

            if (request.DateFrom.HasValue)
            {
                var dateFrom = request.DateFrom.Value.Date;
                query = query.Where(transaction => transaction.CreatedAtUtc >= dateFrom);
            }

            if (request.DateTo.HasValue)
            {
                var dateTo = request.DateTo.Value.Date.AddDays(1);
                query = query.Where(transaction => transaction.CreatedAtUtc < dateTo);
            }

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                var matchingAccountIds = dbContext.Accounts
                    .Where(account =>
                        account.AccountNumber.Contains(search) ||
                        account.User.FirstName.Contains(search) ||
                        account.User.LastName.Contains(search) ||
                        account.User.Email.Contains(search))
                    .Select(account => account.Id);

                query = query.Where(transaction =>
                    transaction.ReferenceNumber.Contains(search) ||
                    transaction.Description.Contains(search) ||
                    matchingAccountIds.Contains(transaction.AccountId) ||
                    (transaction.SourceAccountId.HasValue &&
                        matchingAccountIds.Contains(transaction.SourceAccountId.Value)) ||
                    (transaction.DestinationAccountId.HasValue &&
                        matchingAccountIds.Contains(transaction.DestinationAccountId.Value)));
            }

            return query;
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
                SourceAccountId = transaction.SourceAccountId,
                DestinationAccountId = transaction.DestinationAccountId,
                ReferenceNumber = transaction.ReferenceNumber,
                Amount = transaction.Amount,
                Description = transaction.Description,
                Status = transaction.Status,
                CreatedAtUtc = transaction.CreatedAtUtc
            };
        }

        private static TransactionResponse ToResponse(
            Transaction transaction,
            Account sourceAccount,
            Account destinationAccount)
        {
            var response = ToResponse(transaction);
            response.SourceAccountNumber = sourceAccount.AccountNumber;
            response.DestinationAccountNumber = destinationAccount.AccountNumber;
            response.SourceCustomerName = ToCustomerName(sourceAccount);
            response.DestinationCustomerName = ToCustomerName(destinationAccount);
            return response;
        }

        private static TransferAccountResponse ToTransferAccountResponse(Account account)
        {
            return new TransferAccountResponse
            {
                Id = account.Id,
                AccountNumber = account.AccountNumber,
                Balance = account.Balance,
                Currency = account.Currency
            };
        }

        public async Task<TransactionSummaryResponse> GetSummaryAsync(
            TransactionQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.Transactions
                .AsNoTracking()
                .Include(transaction => transaction.Account)
                .AsQueryable();

            query = ApplyQuery(request, query);
            var completedQuery = query.Where(transaction => transaction.Status == TransactionStatus.Completed);

            return new TransactionSummaryResponse
            {
                TotalTransactions = await query.CountAsync(cancellationToken),
                CompletedTransactions = await completedQuery.CountAsync(cancellationToken),
                TotalTransferred = await completedQuery
                    .SumAsync(transaction => transaction.Amount < 0 ? -transaction.Amount : transaction.Amount, cancellationToken)
            };
        }

        private async Task PopulateTransferDetailsAsync(
            IReadOnlyCollection<TransactionResponse> responses,
            CancellationToken cancellationToken)
        {
            var accountIds = responses
                .SelectMany(response => new[] { response.SourceAccountId, response.DestinationAccountId })
                .Where(accountId => accountId.HasValue)
                .Select(accountId => accountId!.Value)
                .Distinct()
                .ToList();

            if (accountIds.Count == 0)
            {
                return;
            }

            var accounts = await dbContext.Accounts
                .AsNoTracking()
                .Include(account => account.User)
                .Where(account => accountIds.Contains(account.Id))
                .ToDictionaryAsync(account => account.Id, cancellationToken);

            foreach (var response in responses)
            {
                if (response.SourceAccountId.HasValue &&
                    accounts.TryGetValue(response.SourceAccountId.Value, out var sourceAccount))
                {
                    response.SourceAccountNumber = sourceAccount.AccountNumber;
                    response.SourceCustomerName = ToCustomerName(sourceAccount);
                }

                if (response.DestinationAccountId.HasValue &&
                    accounts.TryGetValue(response.DestinationAccountId.Value, out var destinationAccount))
                {
                    response.DestinationAccountNumber = destinationAccount.AccountNumber;
                    response.DestinationCustomerName = ToCustomerName(destinationAccount);
                }
            }
        }

        private static string ToCustomerName(Account account)
        {
            if (account.User is null)
            {
                return string.Empty;
            }

            return $"{account.User.FirstName} {account.User.LastName}".Trim();
        }
    }
}
