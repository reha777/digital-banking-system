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
        ICurrentUserService currentUserService,
        ICurrencyConversionService currencyConversionService) : ITransactionService
    {
        private const decimal HighRiskReviewThreshold = 10000m;

        public async Task<PagedResult<TransactionResponse>> GetAsync(
            TransactionQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.Transactions
                .AsNoTracking()
                .Include(transaction => transaction.Account)
                .Include(transaction => transaction.Documents)
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
                Type = TransactionType.Transfer,
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

            var quote = await QuoteAsync(new MoneyTransferQuoteRequest
            {
                SourceAccountId = request.SourceAccountId,
                DestinationAccountNumber = request.DestinationAccountNumber,
                Amount = request.Amount,
                Currency = request.Currency
            }, cancellationToken);

            var sourceAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(
                    account =>
                        account.Id == request.SourceAccountId &&
                        account.UserId == currentUserService.UserId,
                    cancellationToken)
                ?? throw new NotFoundException("Racun sa kojeg saljete novac nije pronadjen.");

            var destinationAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(
                    account => account.AccountNumber == request.DestinationAccountNumber.Trim(),
                    cancellationToken)
                ?? throw new NotFoundException("Racun primaoca nije pronadjen.");

            if (sourceAccount.Balance < quote.DebitAmount)
            {
                throw new BusinessException("Nedovoljno sredstava na racunu.");
            }

            var referenceNumber = CreateReferenceNumber();
            var createdAtUtc = DateTime.UtcNow;
            var description = string.IsNullOrWhiteSpace(request.Description)
                ? $"Transfer to {destinationAccount.AccountNumber}"
                : request.Description.Trim();

            var riskAmountBam = currencyConversionService.ToBam(request.Amount, quote.TransferCurrency);
            var requiresReview = riskAmountBam > HighRiskReviewThreshold;

            var debitTransaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = sourceAccount.Id,
                SourceAccountId = sourceAccount.Id,
                DestinationAccountId = destinationAccount.Id,
                ReferenceNumber = referenceNumber,
                Amount = -quote.DebitAmount,
                Type = TransactionType.Transfer,
                TransferAmount = quote.Amount,
                TransferCurrency = quote.TransferCurrency,
                DestinationAmount = quote.DestinationAmount,
                Description = description,
                Status = requiresReview ? TransactionStatus.Pending : TransactionStatus.Completed,
                IsHighRiskReview = requiresReview,
                ReviewReason = requiresReview
                    ? $"Transfer value exceeds {HighRiskReviewThreshold:N2} BAM review threshold."
                    : null,
                CreatedAtUtc = createdAtUtc
            };

            Transaction? creditTransaction = null;
            if (!requiresReview)
            {
                sourceAccount.Balance -= quote.DebitAmount;
                destinationAccount.Balance += quote.DestinationAmount;

                creditTransaction = new Transaction
                {
                    Id = Guid.NewGuid(),
                    AccountId = destinationAccount.Id,
                    SourceAccountId = sourceAccount.Id,
                    DestinationAccountId = destinationAccount.Id,
                    ReferenceNumber = referenceNumber,
                    Amount = quote.DestinationAmount,
                    Type = TransactionType.Transfer,
                    TransferAmount = quote.Amount,
                    TransferCurrency = quote.TransferCurrency,
                    DestinationAmount = quote.DestinationAmount,
                    Description = $"Transfer from {sourceAccount.AccountNumber}",
                    Status = TransactionStatus.Completed,
                    CreatedAtUtc = createdAtUtc
                };
            }

            dbContext.Transactions.Add(debitTransaction);
            if (creditTransaction is not null)
            {
                dbContext.Transactions.Add(creditTransaction);
            }
            await dbContext.SaveChangesAsync(cancellationToken);

            debitTransaction.Account = sourceAccount;
            if (creditTransaction is not null)
            {
                creditTransaction.Account = destinationAccount;
            }

            return new MoneyTransferResponse
            {
                ReferenceNumber = referenceNumber,
                Status = debitTransaction.Status,
                Amount = request.Amount,
                Currency = quote.TransferCurrency,
                Quote = quote,
                SourceAccount = ToTransferAccountResponse(sourceAccount),
                DestinationAccount = ToTransferAccountResponse(destinationAccount),
                DebitTransaction = ToResponse(debitTransaction, sourceAccount, destinationAccount),
                CreditTransaction = creditTransaction is null
                    ? new TransactionResponse()
                    : ToResponse(creditTransaction, sourceAccount, destinationAccount),
                CreatedAtUtc = createdAtUtc
            };
        }

        public async Task<MoneyTransferQuoteResponse> QuoteAsync(
            MoneyTransferQuoteRequest request,
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
                throw new BusinessException("Admin korisnik ne moze slati novac u ime klijenta.");
            if (request.Amount <= 0)
                throw new BusinessException("Iznos za slanje mora biti veci od nule.");

            var transferCurrency = request.Currency.Trim().ToUpperInvariant();
            if (!currencyConversionService.IsSupported(transferCurrency))
                throw new BusinessException("Valuta nije podrzana. Dozvoljene valute su USD, EUR i BAM.");

            var source = await dbContext.Accounts.AsNoTracking()
                .FirstOrDefaultAsync(account =>
                    account.Id == request.SourceAccountId &&
                    account.UserId == currentUserService.UserId, cancellationToken)
                ?? throw new NotFoundException("Racun sa kojeg saljete novac nije pronadjen.");

            var cardStatus = await dbContext.BankCards.AsNoTracking()
                .Where(card => card.AccountId == source.Id)
                .Select(card => (CardStatus?)card.Status)
                .SingleOrDefaultAsync(cancellationToken);
            if (cardStatus.HasValue && cardStatus != CardStatus.Active)
                throw new BusinessException("Transfer nije dozvoljen sa blokirane ili istekle kartice.");

            var destinationNumber = request.DestinationAccountNumber.Trim();
            if (string.IsNullOrWhiteSpace(destinationNumber))
                throw new BusinessException("Racun primaoca je obavezan.");
            var destination = await dbContext.Accounts.AsNoTracking()
                .FirstOrDefaultAsync(account => account.AccountNumber == destinationNumber, cancellationToken)
                ?? throw new NotFoundException("Racun primaoca nije pronadjen.");
            if (source.Id == destination.Id)
                throw new BusinessException("Novac nije moguce poslati na isti racun.");
            if (source.UserId == destination.UserId)
                throw new BusinessException("Novac nije moguce poslati samom sebi.");

            return new MoneyTransferQuoteResponse
            {
                SourceCurrency = source.Currency,
                TransferCurrency = transferCurrency,
                DestinationCurrency = destination.Currency,
                Amount = decimal.Round(request.Amount, 2, MidpointRounding.AwayFromZero),
                ExchangeRate = currencyConversionService.GetRate(transferCurrency, source.Currency),
                DebitAmount = currencyConversionService.Convert(request.Amount, transferCurrency, source.Currency),
                DestinationAmount = currencyConversionService.Convert(request.Amount, transferCurrency, destination.Currency),
                RequiresConversion = transferCurrency != source.Currency || transferCurrency != destination.Currency
            };
        }

        public async Task<MoneyTransferQuoteResponse> QuoteInternalTransferAsync(
            InternalTransferQuoteRequest request,
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
                throw new BusinessException("Admin korisnik ne moze prebacivati novac izmedju racuna.");
            if (request.Amount <= 0)
                throw new BusinessException("Iznos transfera mora biti veci od nule.");
            if (request.SourceAccountId == request.DestinationAccountId)
                throw new BusinessException("Izvorni i odredisni racun moraju biti razliciti.");

            var accounts = await dbContext.Accounts
                .AsNoTracking()
                .Where(account =>
                    account.Id == request.SourceAccountId ||
                    account.Id == request.DestinationAccountId)
                .ToListAsync(cancellationToken);
            var source = accounts.SingleOrDefault(account => account.Id == request.SourceAccountId)
                ?? throw new NotFoundException("Izvorni racun nije pronadjen.");
            var destination = accounts.SingleOrDefault(account => account.Id == request.DestinationAccountId)
                ?? throw new NotFoundException("Odredisni racun nije pronadjen.");

            if (source.UserId != currentUserService.UserId)
                throw new BusinessException("Izvorni racun ne pripada prijavljenom korisniku.");
            if (destination.UserId != currentUserService.UserId)
                throw new BusinessException("Odredisni racun ne pripada prijavljenom korisniku.");
            return BuildInternalTransferQuote(source, destination, request.Amount);
        }

        public async Task<MoneyTransferResponse> InternalTransferAsync(
            InternalTransferRequest request,
            CancellationToken cancellationToken = default)
        {
            var strategy = dbContext.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                await using var databaseTransaction = dbContext.Database.IsRelational()
                    ? await dbContext.Database.BeginTransactionAsync(
                        System.Data.IsolationLevel.Serializable,
                        cancellationToken)
                    : null;

                try
                {
                    if (currentUserService.IsAdmin)
                        throw new BusinessException("Admin korisnik ne moze prebacivati novac izmedju racuna.");
                    if (request.Amount <= 0)
                        throw new BusinessException("Iznos transfera mora biti veci od nule.");
                    if (request.SourceAccountId == request.DestinationAccountId)
                        throw new BusinessException("Izvorni i odredisni racun moraju biti razliciti.");

                    var accounts = await dbContext.Accounts
                        .Where(account =>
                            account.Id == request.SourceAccountId ||
                            account.Id == request.DestinationAccountId)
                        .ToListAsync(cancellationToken);
                    var source = accounts.SingleOrDefault(account => account.Id == request.SourceAccountId)
                        ?? throw new NotFoundException("Izvorni racun nije pronadjen.");
                    var destination = accounts.SingleOrDefault(account => account.Id == request.DestinationAccountId)
                        ?? throw new NotFoundException("Odredisni racun nije pronadjen.");

                    if (source.UserId != currentUserService.UserId ||
                        destination.UserId != currentUserService.UserId)
                        throw new BusinessException("Oba racuna moraju pripadati prijavljenom korisniku.");

                    var quote = BuildInternalTransferQuote(source, destination, request.Amount);
                    var referenceNumber = CreateReferenceNumber();
                    var createdAtUtc = DateTime.UtcNow;
                    var description = string.IsNullOrWhiteSpace(request.Description)
                        ? "Transfer between my accounts"
                        : request.Description.Trim();

                    source.Balance -= quote.DebitAmount;
                    destination.Balance += quote.DestinationAmount;

                    var debitTransaction = new Transaction
                    {
                        Id = Guid.NewGuid(),
                        AccountId = source.Id,
                        SourceAccountId = source.Id,
                        DestinationAccountId = destination.Id,
                        ReferenceNumber = referenceNumber,
                        Amount = -quote.DebitAmount,
                        Type = TransactionType.InternalTransfer,
                        TransferAmount = quote.Amount,
                        TransferCurrency = quote.TransferCurrency,
                        DestinationAmount = quote.DestinationAmount,
                        Description = description,
                        Status = TransactionStatus.Completed,
                        IsHighRiskReview = false,
                        CreatedAtUtc = createdAtUtc
                    };
                    var creditTransaction = new Transaction
                    {
                        Id = Guid.NewGuid(),
                        AccountId = destination.Id,
                        SourceAccountId = source.Id,
                        DestinationAccountId = destination.Id,
                        ReferenceNumber = referenceNumber,
                        Amount = quote.DestinationAmount,
                        Type = TransactionType.InternalTransfer,
                        TransferAmount = quote.Amount,
                        TransferCurrency = quote.TransferCurrency,
                        DestinationAmount = quote.DestinationAmount,
                        Description = $"Internal transfer from {source.AccountNumber}",
                        Status = TransactionStatus.Completed,
                        IsHighRiskReview = false,
                        CreatedAtUtc = createdAtUtc
                    };

                    dbContext.Transactions.AddRange(debitTransaction, creditTransaction);
                    await dbContext.SaveChangesAsync(cancellationToken);
                    if (databaseTransaction is not null)
                        await databaseTransaction.CommitAsync(cancellationToken);

                    debitTransaction.Account = source;
                    creditTransaction.Account = destination;
                    return new MoneyTransferResponse
                    {
                        ReferenceNumber = referenceNumber,
                        Status = TransactionStatus.Completed,
                        Amount = quote.Amount,
                        Currency = quote.TransferCurrency,
                        Quote = quote,
                        SourceAccount = ToTransferAccountResponse(source),
                        DestinationAccount = ToTransferAccountResponse(destination),
                        DebitTransaction = ToResponse(debitTransaction, source, destination),
                        CreditTransaction = ToResponse(creditTransaction, source, destination),
                        CreatedAtUtc = createdAtUtc
                    };
                }
                catch
                {
                    if (databaseTransaction is not null)
                        await databaseTransaction.RollbackAsync(cancellationToken);
                    dbContext.ChangeTracker.Clear();
                    throw;
                }
            });
        }

        private MoneyTransferQuoteResponse BuildInternalTransferQuote(
            Account source,
            Account destination,
            decimal requestedAmount)
        {
            if (!currencyConversionService.IsSupported(source.Currency) ||
                !currencyConversionService.IsSupported(destination.Currency))
                throw new BusinessException("Valuta nije podrzana. Dozvoljene valute su USD, EUR i BAM.");

            var amount = decimal.Round(requestedAmount, 2, MidpointRounding.AwayFromZero);
            if (amount <= 0)
                throw new BusinessException("Iznos transfera mora biti najmanje 0.01.");
            if (source.Balance < amount)
                throw new BusinessException("Nedovoljno sredstava na racunu.");

            return new MoneyTransferQuoteResponse
            {
                SourceCurrency = source.Currency,
                TransferCurrency = source.Currency,
                DestinationCurrency = destination.Currency,
                Amount = amount,
                ExchangeRate = currencyConversionService.GetRate(
                    source.Currency,
                    destination.Currency),
                DebitAmount = amount,
                DestinationAmount = currencyConversionService.Convert(
                    amount,
                    source.Currency,
                    destination.Currency),
                RequiresConversion = !source.Currency.Equals(
                    destination.Currency,
                    StringComparison.OrdinalIgnoreCase)
            };
        }

        public async Task<IReadOnlyCollection<RecentRecipientResponse>> GetRecentRecipientsAsync(
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
                throw new BusinessException("Admin korisnik nema recent primaoce.");

            var outgoing = await dbContext.Transactions
                .AsNoTracking()
                .Where(transaction =>
                    transaction.Account.UserId == currentUserService.UserId &&
                    transaction.Amount < 0 &&
                    (transaction.Status == TransactionStatus.Completed ||
                        transaction.Status == TransactionStatus.Pending) &&
                    transaction.DestinationAccountId != null)
                .OrderByDescending(transaction => transaction.CreatedAtUtc)
                .Select(transaction => new
                {
                    DestinationAccountId = transaction.DestinationAccountId!.Value,
                    transaction.CreatedAtUtc
                })
                .Take(100)
                .ToListAsync(cancellationToken);

            var latestByAccount = outgoing
                .GroupBy(item => item.DestinationAccountId)
                .Select(group => group.First())
                .Take(8)
                .ToList();
            if (latestByAccount.Count == 0) return [];

            var ids = latestByAccount.Select(item => item.DestinationAccountId).ToList();
            var accounts = await dbContext.Accounts
                .AsNoTracking()
                .Include(account => account.User)
                .Where(account => ids.Contains(account.Id))
                .ToDictionaryAsync(account => account.Id, cancellationToken);

            return latestByAccount
                .Where(item => accounts.ContainsKey(item.DestinationAccountId))
                .Select(item => ToRecipient(accounts[item.DestinationAccountId], item.CreatedAtUtc))
                .ToList();
        }

        public async Task<RecentRecipientResponse> LookupRecipientAsync(
            string accountNumber,
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
                throw new BusinessException("Admin korisnik ne moze traziti primaoce.");
            var normalized = accountNumber.Trim();
            if (string.IsNullOrWhiteSpace(normalized))
                throw new BusinessException("Racun primaoca je obavezan.");

            var account = await dbContext.Accounts
                .AsNoTracking()
                .Include(value => value.User)
                .SingleOrDefaultAsync(value => value.AccountNumber == normalized, cancellationToken)
                ?? throw new NotFoundException("Racun primaoca nije pronadjen.");
            if (account.UserId == currentUserService.UserId)
                throw new BusinessException("Novac nije moguce poslati samom sebi.");
            return ToRecipient(account, null);
        }

        private static RecentRecipientResponse ToRecipient(Account account, DateTime? lastUsedAtUtc) =>
            new(account.Id, account.User.FirstName, account.User.LastName,
                account.AccountNumber, lastUsedAtUtc);

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

        public async Task<TransactionResponse> ApproveReviewAsync(
            Guid id,
            TransactionReviewRequest request,
            CancellationToken cancellationToken = default)
        {
            var transaction = await GetReviewTransactionAsync(id, cancellationToken);

            if (transaction.Status is not (TransactionStatus.Pending or TransactionStatus.DocumentsRequested))
            {
                throw new BusinessException("Samo transakcija koja ceka review moze biti odobrena.");
            }

            var sourceAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(account => account.Id == transaction.SourceAccountId, cancellationToken)
                ?? throw new NotFoundException("Racun posiljaoca nije pronadjen.");

            var destinationAccount = await dbContext.Accounts
                .FirstOrDefaultAsync(account => account.Id == transaction.DestinationAccountId, cancellationToken)
                ?? throw new NotFoundException("Racun primaoca nije pronadjen.");

            var amount = Math.Abs(transaction.Amount);
            var destinationAmount = transaction.DestinationAmount ?? amount;
            if (sourceAccount.Balance < amount)
            {
                throw new BusinessException("Nedovoljno sredstava za odobrenje transakcije.");
            }

            sourceAccount.Balance -= amount;
            destinationAccount.Balance += destinationAmount;

            transaction.Status = TransactionStatus.Completed;
            transaction.AdminNote = request.AdminNote?.Trim();
            transaction.ReviewedAtUtc = DateTime.UtcNow;
            transaction.ReviewedByUserId = currentUserService.UserId;

            var creditTransaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = destinationAccount.Id,
                SourceAccountId = sourceAccount.Id,
                DestinationAccountId = destinationAccount.Id,
                ReferenceNumber = transaction.ReferenceNumber,
                Amount = destinationAmount,
                Type = TransactionType.Transfer,
                TransferAmount = transaction.TransferAmount,
                TransferCurrency = transaction.TransferCurrency,
                DestinationAmount = destinationAmount,
                Description = $"Transfer from {sourceAccount.AccountNumber}",
                Status = TransactionStatus.Completed,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.Transactions.Add(creditTransaction);
            await dbContext.SaveChangesAsync(cancellationToken);

            transaction.Account = sourceAccount;
            var response = ToResponse(transaction, sourceAccount, destinationAccount);
            response.AdminNote = transaction.AdminNote;
            response.ReviewedAtUtc = transaction.ReviewedAtUtc;
            response.Documents = transaction.Documents.Select(ToDocumentResponse).ToList();
            return response;
        }

        public async Task<TransactionResponse> RejectReviewAsync(
            Guid id,
            TransactionReviewRequest request,
            CancellationToken cancellationToken = default)
        {
            var transaction = await GetReviewTransactionAsync(id, cancellationToken);

            if (transaction.Status is not (TransactionStatus.Pending or TransactionStatus.DocumentsRequested))
            {
                throw new BusinessException("Samo transakcija koja ceka review moze biti odbijena.");
            }

            transaction.Status = TransactionStatus.Failed;
            transaction.AdminNote = request.AdminNote?.Trim();
            transaction.ReviewedAtUtc = DateTime.UtcNow;
            transaction.ReviewedByUserId = currentUserService.UserId;

            await dbContext.SaveChangesAsync(cancellationToken);

            var response = ToResponse(transaction);
            await PopulateTransferDetailsAsync([response], cancellationToken);
            return response;
        }

        public async Task<TransactionResponse> RequestDocumentsAsync(
            Guid id,
            TransactionDocumentsRequest request,
            CancellationToken cancellationToken = default)
        {
            var transaction = await GetReviewTransactionAsync(id, cancellationToken);

            if (transaction.Status is not (TransactionStatus.Pending or TransactionStatus.DocumentsRequested))
            {
                throw new BusinessException("Dokumenti se mogu traziti samo za transakciju koja ceka review.");
            }

            transaction.Status = TransactionStatus.DocumentsRequested;
            transaction.DocumentsRequestNote = request.AdminNote?.Trim();
            transaction.DocumentsRequestedAtUtc = DateTime.UtcNow;

            await dbContext.SaveChangesAsync(cancellationToken);

            var response = ToResponse(transaction);
            await PopulateTransferDetailsAsync([response], cancellationToken);
            return response;
        }

        public async Task<TransactionResponse> UploadDocumentAsync(
            Guid id,
            TransactionDocumentUploadRequest request,
            CancellationToken cancellationToken = default)
        {
            if (request.Content.Length == 0)
            {
                throw new BusinessException("Dokument ne moze biti prazan.");
            }

            if (request.Content.Length > 5 * 1024 * 1024)
            {
                throw new BusinessException("Dokument moze biti maksimalno 5 MB.");
            }

            var transaction = await dbContext.Transactions
                .Include(item => item.Account)
                .Include(item => item.Documents)
                .FirstOrDefaultAsync(
                    item =>
                        item.Id == id &&
                        item.Account.UserId == currentUserService.UserId &&
                        item.IsHighRiskReview,
                    cancellationToken);

            if (transaction is null)
            {
                throw new NotFoundException("Transakcija nije pronadjena.");
            }

            if (transaction.Status != TransactionStatus.DocumentsRequested)
            {
                throw new BusinessException("Dokumenti se mogu dodati tek nakon sto ih admin zatrazi.");
            }

            var document = new TransactionDocument
            {
                Id = Guid.NewGuid(),
                TransactionId = transaction.Id,
                FileName = request.FileName.Trim(),
                ContentType = request.ContentType.Trim(),
                SizeBytes = request.Content.LongLength,
                Content = request.Content,
                UploadedAtUtc = DateTime.UtcNow
            };

            dbContext.TransactionDocuments.Add(document);
            await dbContext.SaveChangesAsync(cancellationToken);

            transaction.Documents.Add(document);
            var response = ToResponse(transaction);
            await PopulateTransferDetailsAsync([response], cancellationToken);
            return response;
        }

        public async Task<TransactionDocumentDownloadResponse> DownloadDocumentAsync(
            Guid transactionId,
            Guid documentId,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.TransactionDocuments
                .AsNoTracking()
                .Include(document => document.Transaction)
                .ThenInclude(transaction => transaction.Account)
                .Where(document =>
                    document.Id == documentId &&
                    document.TransactionId == transactionId);

            if (!currentUserService.IsAdmin)
            {
                query = query.Where(document =>
                    document.Transaction.Account.UserId == currentUserService.UserId);
            }

            var document = await query.FirstOrDefaultAsync(cancellationToken);
            if (document is null)
            {
                throw new NotFoundException("Dokument nije pronadjen.");
            }

            return new TransactionDocumentDownloadResponse
            {
                FileName = document.FileName,
                ContentType = document.ContentType,
                Content = document.Content
            };
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

            if (request.HighRiskOnly == true)
            {
                query = query.Where(transaction => transaction.IsHighRiskReview);
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
                .Include(item => item.Documents)
                .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

            return transaction ?? throw new NotFoundException("Transakcija nije pronadjena.");
        }

        private async Task<Transaction> GetReviewTransactionAsync(
            Guid id,
            CancellationToken cancellationToken)
        {
            if (!currentUserService.IsAdmin)
            {
                throw new BusinessException("Samo admin moze pregledati high-risk transakcije.");
            }

            var transaction = await dbContext.Transactions
                .Include(item => item.Account)
                .Include(item => item.Documents)
                .FirstOrDefaultAsync(
                    item =>
                        item.Id == id &&
                        item.IsHighRiskReview &&
                        item.SourceAccountId.HasValue &&
                        item.DestinationAccountId.HasValue,
                    cancellationToken);

            return transaction ?? throw new NotFoundException("Transakcija za review nije pronadjena.");
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
                Type = transaction.Type,
                Description = transaction.Description,
                Status = transaction.Status,
                IsHighRiskReview = transaction.IsHighRiskReview,
                ReviewReason = transaction.ReviewReason,
                DocumentsRequestNote = transaction.DocumentsRequestNote,
                DocumentsRequestedAtUtc = transaction.DocumentsRequestedAtUtc,
                AdminNote = transaction.AdminNote,
                ReviewedAtUtc = transaction.ReviewedAtUtc,
                CreatedAtUtc = transaction.CreatedAtUtc,
                Documents = transaction.Documents
                    .OrderByDescending(document => document.UploadedAtUtc)
                    .Select(ToDocumentResponse)
                    .ToList()
            };
        }

        private static TransactionDocumentResponse ToDocumentResponse(TransactionDocument document)
        {
            return new TransactionDocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                SizeBytes = document.SizeBytes,
                UploadedAtUtc = document.UploadedAtUtc
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

        public async Task<TransactionStatisticsResponse> GetStatisticsAsync(
            TransactionStatisticsQuery request,
            CancellationToken cancellationToken = default)
        {
            if (currentUserService.IsAdmin)
                throw new BusinessException("Statistics je dostupan samo customer korisnicima.");

            var fromUtc = DateTime.SpecifyKind(request.From.Date, DateTimeKind.Utc);
            var toUtc = DateTime.SpecifyKind(request.To.Date, DateTimeKind.Utc);
            if (fromUtc == default || toUtc == default || toUtc <= fromUtc)
                throw new BusinessException("Statistics period nije validan.");
            if (toUtc > fromUtc.AddMonths(12))
                throw new BusinessException("Statistics period ne moze biti duzi od 12 mjeseci.");

            var accounts = await dbContext.Accounts
                .AsNoTracking()
                .Where(account => account.UserId == currentUserService.UserId)
                .OrderBy(account => account.AccountNumber)
                .ToListAsync(cancellationToken);

            if (request.AccountId.HasValue &&
                accounts.All(account => account.Id != request.AccountId.Value))
                throw new NotFoundException("Racun za statistics nije pronadjen.");

            var selectedAccounts = request.AccountId.HasValue
                ? accounts.Where(account => account.Id == request.AccountId.Value).ToList()
                : accounts;
            var selectedAccountIds = selectedAccounts.Select(account => account.Id).ToList();
            var allOwnedAccountIds = accounts.Select(account => account.Id).ToHashSet();

            var transactions = await dbContext.Transactions
                .AsNoTracking()
                .Include(transaction => transaction.Account)
                .Where(transaction =>
                    selectedAccountIds.Contains(transaction.AccountId) &&
                    transaction.Status == TransactionStatus.Completed &&
                    transaction.CreatedAtUtc >= fromUtc &&
                    transaction.CreatedAtUtc < toUtc)
                .OrderByDescending(transaction => transaction.CreatedAtUtc)
                .ToListAsync(cancellationToken);

            if (!request.AccountId.HasValue)
            {
                transactions = transactions
                    .Where(transaction => !(
                        transaction.SourceAccountId.HasValue &&
                        transaction.DestinationAccountId.HasValue &&
                        allOwnedAccountIds.Contains(transaction.SourceAccountId.Value) &&
                        allOwnedAccountIds.Contains(transaction.DestinationAccountId.Value)))
                    .ToList();
            }

            var monthStarts = new List<DateTime>();
            for (var month = new DateTime(fromUtc.Year, fromUtc.Month, 1, 0, 0, 0, DateTimeKind.Utc);
                 month < toUtc;
                 month = month.AddMonths(1))
            {
                monthStarts.Add(month);
            }

            var response = new TransactionStatisticsResponse
            {
                FromUtc = fromUtc,
                ToUtc = toUtc,
                AccountId = request.AccountId,
                Accounts = accounts.Select(account => new StatisticsAccountResponse
                {
                    Id = account.Id,
                    AccountNumber = account.AccountNumber,
                    AccountType = account.AccountType,
                    Balance = account.Balance,
                    Currency = account.Currency
                }).ToList(),
                CurrencySeries = selectedAccounts
                    .GroupBy(account => account.Currency)
                    .OrderBy(group => group.Key)
                    .Select(group =>
                    {
                        var currencyTransactions = transactions
                            .Where(transaction => transaction.Account.Currency == group.Key)
                            .ToList();
                        return new CurrencyStatisticsResponse
                        {
                            Currency = group.Key,
                            Balance = group.Sum(account => account.Balance),
                            Months = monthStarts.Select(month =>
                            {
                                var nextMonth = month.AddMonths(1);
                                var monthlyTransactions = currencyTransactions
                                    .Where(transaction =>
                                        transaction.CreatedAtUtc >= month &&
                                        transaction.CreatedAtUtc < nextMonth)
                                    .ToList();
                                return new MonthlyStatisticsResponse
                                {
                                    Year = month.Year,
                                    Month = month.Month,
                                    Income = monthlyTransactions
                                        .Where(transaction => transaction.Amount > 0)
                                        .Sum(transaction => transaction.Amount),
                                    Spending = monthlyTransactions
                                        .Where(transaction => transaction.Amount < 0)
                                        .Sum(transaction => Math.Abs(transaction.Amount)),
                                    RecentTransactions = monthlyTransactions
                                        .Take(5)
                                        .Select(ToResponse)
                                        .ToList()
                                };
                            }).ToList()
                        };
                    }).ToList()
            };

            var recentResponses = response.CurrencySeries
                .SelectMany(series => series.Months)
                .SelectMany(month => month.RecentTransactions)
                .ToList();
            await PopulateTransferDetailsAsync(recentResponses, cancellationToken);
            return response;
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
