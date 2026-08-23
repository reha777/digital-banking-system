using BankingApp.Application.Cards;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class CardService(
        BankingAppDbContext dbContext,
        ICurrentUserService currentUserService,
        IAuditLogService? auditLogService = null) : ICardService
    {
        public async Task<IReadOnlyCollection<CardResponse>> GetMyCardsAsync(
            CancellationToken cancellationToken = default)
        {
            var cards = await dbContext.BankCards
                .AsNoTracking()
                .Include(card => card.Account)
                .Where(card => card.Account.UserId == currentUserService.UserId)
                .OrderByDescending(card => card.CreatedAtUtc)
                .ToListAsync(cancellationToken);

            return cards.Select(ToCardResponse).ToList();
        }

        public async Task<CardSensitiveDataResponse> GetSensitiveDataAsync(
            Guid id,
            CancellationToken cancellationToken = default)
        {
            var card = await dbContext.BankCards.AsNoTracking()
                .FirstOrDefaultAsync(item =>
                    item.Id == id && item.Account.UserId == currentUserService.UserId,
                    cancellationToken)
                ?? throw new NotFoundException("Kartica nije pronadjena.");

            return new CardSensitiveDataResponse
            {
                Id = card.Id,
                CardNumber = card.CardNumber,
                Cvv = card.Cvv
            };
        }

        public async Task<CardResponse> SetFrozenAsync(
            Guid id,
            bool frozen,
            CancellationToken cancellationToken = default)
        {
            var card = await dbContext.BankCards.Include(item => item.Account)
                .FirstOrDefaultAsync(item =>
                    item.Id == id && item.Account.UserId == currentUserService.UserId,
                    cancellationToken)
                ?? throw new NotFoundException("Kartica nije pronadjena.");

            if (card.Status == CardStatus.Expired)
                throw new BusinessException("Istekla kartica ne moze promijeniti status.");

            card.Status = frozen ? CardStatus.Blocked : CardStatus.Active;
            await dbContext.SaveChangesAsync(cancellationToken);
            return ToCardResponse(card);
        }

        public async Task<CardRequestResponse> CreateRequestAsync(
            CardRequestCreateRequest request,
            CancellationToken cancellationToken = default)
        {
            var customer = await dbContext.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    user =>
                        user.Id == currentUserService.UserId &&
                        user.Role == AppRoles.Customer &&
                        !user.IsDeleted &&
                        user.Status == CustomerStatus.Active,
                    cancellationToken);

            if (customer == null)
            {
                throw new BusinessException("Samo aktivan klijent moze poslati zahtjev za karticu.");
            }

            var hasPendingRequest = await dbContext.CardRequests.AnyAsync(
                cardRequest =>
                    cardRequest.UserId == currentUserService.UserId &&
                    (cardRequest.Status == CardRequestStatus.Pending ||
                        cardRequest.Status == CardRequestStatus.DocumentsRequested),
                cancellationToken);

            if (hasPendingRequest)
            {
                throw new BusinessException("Vec imate zahtjev za karticu koji ceka odobrenje.");
            }

            var cardRequest = new CardRequest
            {
                Id = Guid.NewGuid(),
                UserId = currentUserService.UserId,
                CardholderName = request.CardholderName.Trim(),
                Currency = request.Currency.Trim().ToUpperInvariant(),
                DocumentNumber = request.DocumentNumber.Trim(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                Note = request.Note?.Trim() ?? string.Empty,
                Status = CardRequestStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.CardRequests.Add(cardRequest);
            await dbContext.SaveChangesAsync(cancellationToken);

            cardRequest.User = customer;
            return ToRequestResponse(cardRequest);
        }

        public Task<PagedResult<CardRequestResponse>> GetMyRequestsAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = BaseRequestQuery()
                .Where(cardRequest => cardRequest.UserId == currentUserService.UserId);

            return GetPagedRequestsAsync(request, query, cancellationToken);
        }

        public Task<PagedResult<CardRequestResponse>> GetRequestsAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            return GetPagedRequestsAsync(request, BaseRequestQuery(), cancellationToken);
        }

        public async Task<CardRequestSummaryResponse> GetRequestSummaryAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = ApplyQuery(request, BaseRequestQuery());

            return new CardRequestSummaryResponse
            {
                TotalRequests = await query.CountAsync(cancellationToken),
                PendingRequests = await query.CountAsync(
                    cardRequest =>
                        cardRequest.Status == CardRequestStatus.Pending ||
                        cardRequest.Status == CardRequestStatus.DocumentsRequested,
                    cancellationToken),
                ApprovedRequests = await query.CountAsync(
                    cardRequest => cardRequest.Status == CardRequestStatus.Approved,
                    cancellationToken),
                RejectedRequests = await query.CountAsync(
                    cardRequest => cardRequest.Status == CardRequestStatus.Rejected,
                    cancellationToken),
                DocumentsRequestedRequests = await query.CountAsync(
                    cardRequest => cardRequest.Status == CardRequestStatus.DocumentsRequested,
                    cancellationToken)
            };
        }

        public async Task<PagedResult<AdminIssuedCardResponse>> GetIssuedCardsAsync(
            AdminIssuedCardQueryRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.BankCards
                .AsNoTracking()
                .Include(card => card.Account)
                    .ThenInclude(account => account.User)
                .AsQueryable();

            if (request.Status.HasValue)
                query = query.Where(card => card.Status == request.Status.Value);

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(card =>
                    card.CardholderName.Contains(search) ||
                    card.CardNumber.EndsWith(search) ||
                    card.Account.AccountNumber.Contains(search) ||
                    card.Account.Currency.Contains(search) ||
                    card.Account.User.FirstName.Contains(search) ||
                    card.Account.User.LastName.Contains(search) ||
                    card.Account.User.Email.Contains(search));
            }

            var totalCount = await query.CountAsync(cancellationToken);
            var cards = await query
                .OrderByDescending(card => card.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .Select(card => new AdminIssuedCardResponse
                {
                    Id = card.Id,
                    CustomerId = card.Account.UserId,
                    CustomerName = (card.Account.User.FirstName + " " + card.Account.User.LastName).Trim(),
                    CustomerEmail = card.Account.User.Email,
                    MaskedCardNumber = "**** **** **** " + card.CardNumber.Substring(card.CardNumber.Length - 4),
                    CardholderName = card.CardholderName,
                    Brand = card.Brand,
                    ExpiryDate = card.ExpiryDate,
                    Status = card.Status,
                    AccountId = card.AccountId,
                    AccountNumber = card.Account.AccountNumber,
                    Currency = card.Account.Currency,
                    CreatedAtUtc = card.CreatedAtUtc
                })
                .ToListAsync(cancellationToken);

            return new PagedResult<AdminIssuedCardResponse>
            {
                Items = cards,
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        public async Task<CardRequestResponse> ApproveAsync(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken = default)
        {
            var cardRequest = await GetRequestForReviewAsync(id, cancellationToken);

            if (!CanReview(cardRequest.Status))
            {
                throw new BusinessException("Samo zahtjev koji ceka odobrenje moze biti odobren.");
            }

            var account = new Account
            {
                Id = Guid.NewGuid(),
                UserId = cardRequest.UserId,
                AccountNumber = await GenerateAccountNumberAsync(cancellationToken),
                AccountType = AccountType.Checking,
                Balance = 0,
                Currency = cardRequest.Currency,
                CreatedAtUtc = DateTime.UtcNow
            };

            var card = new BankCard
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                CardNumber = await GenerateCardNumberAsync(cancellationToken),
                CardholderName = cardRequest.CardholderName,
                Cvv = GenerateCvv(),
                ExpiryDate = DateTime.UtcNow.Date.AddYears(4),
                Brand = CardBrand.Mastercard,
                Status = CardStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };

            cardRequest.Status = CardRequestStatus.Approved;
            cardRequest.AdminNote = request.AdminNote?.Trim();
            cardRequest.ApprovedAccountId = account.Id;
            cardRequest.ApprovedCardId = card.Id;
            cardRequest.ReviewedAtUtc = DateTime.UtcNow;
            cardRequest.ReviewedByUserId = currentUserService.UserId;

            dbContext.Accounts.Add(account);
            dbContext.BankCards.Add(card);
            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardRequestApproved, EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(), Description = "Card request approved.", Reason = cardRequest.AdminNote
                }, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);

            cardRequest.ApprovedAccount = account;
            cardRequest.ApprovedCard = card;
            return ToRequestResponse(cardRequest);
        }

        public async Task<CardRequestResponse> RejectAsync(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken = default)
        {
            var cardRequest = await GetRequestForReviewAsync(id, cancellationToken);

            if (!CanReview(cardRequest.Status))
            {
                throw new BusinessException("Samo zahtjev koji ceka odobrenje moze biti odbijen.");
            }

            cardRequest.Status = CardRequestStatus.Rejected;
            cardRequest.AdminNote = request.AdminNote?.Trim();
            cardRequest.ReviewedAtUtc = DateTime.UtcNow;
            cardRequest.ReviewedByUserId = currentUserService.UserId;

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardRequestRejected, EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(), Description = "Card request rejected.", Reason = cardRequest.AdminNote
                }, cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToRequestResponse(cardRequest);
        }

        public async Task<CardRequestResponse> RequestDocumentsAsync(
            Guid id,
            CardRequestDocumentsRequest request,
            CancellationToken cancellationToken = default)
        {
            var cardRequest = await GetRequestForReviewAsync(id, cancellationToken);

            if (!CanReview(cardRequest.Status))
            {
                throw new BusinessException("Dokumenti se mogu traziti samo za aktivan zahtjev.");
            }

            cardRequest.Status = CardRequestStatus.DocumentsRequested;
            cardRequest.DocumentsRequestNote = request.AdminNote?.Trim();
            cardRequest.DocumentsRequestedAtUtc = DateTime.UtcNow;

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardDocumentsRequested, EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(), Description = "Card request documents requested.", Reason = cardRequest.DocumentsRequestNote
                }, cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);

            return ToRequestResponse(cardRequest);
        }

        public async Task<CardRequestResponse> UploadDocumentAsync(
            Guid id,
            CardRequestDocumentUploadRequest request,
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

            var cardRequest = await dbContext.CardRequests
                .Include(item => item.User)
                .Include(item => item.ApprovedAccount)
                .Include(item => item.ApprovedCard)
                .Include(item => item.Documents)
                .FirstOrDefaultAsync(
                    item =>
                        item.Id == id &&
                        item.UserId == currentUserService.UserId,
                    cancellationToken);

            if (cardRequest == null)
            {
                throw new NotFoundException("Zahtjev za karticu nije pronadjen.");
            }

            if (!CanReview(cardRequest.Status))
            {
                throw new BusinessException("Dokumenti se mogu dodati samo na aktivan zahtjev.");
            }

            var document = new CardRequestDocument
            {
                Id = Guid.NewGuid(),
                CardRequestId = cardRequest.Id,
                FileName = request.FileName.Trim(),
                ContentType = request.ContentType.Trim(),
                SizeBytes = request.Content.LongLength,
                Content = request.Content,
                UploadedAtUtc = DateTime.UtcNow
            };

            dbContext.CardRequestDocuments.Add(document);
            await dbContext.SaveChangesAsync(cancellationToken);

            cardRequest.Documents.Add(document);
            return ToRequestResponse(cardRequest);
        }

        public async Task<CardRequestDocumentDownloadResponse> DownloadDocumentAsync(
            Guid requestId,
            Guid documentId,
            CancellationToken cancellationToken = default)
        {
            var document = await dbContext.CardRequestDocuments
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    item =>
                        item.Id == documentId &&
                        item.CardRequestId == requestId,
                    cancellationToken);

            if (document == null)
            {
                throw new NotFoundException("Dokument nije pronadjen.");
            }

            return new CardRequestDocumentDownloadResponse
            {
                FileName = document.FileName,
                ContentType = document.ContentType,
                Content = document.Content
            };
        }

        private async Task<PagedResult<CardRequestResponse>> GetPagedRequestsAsync(
            CardRequestQueryRequest request,
            IQueryable<CardRequest> query,
            CancellationToken cancellationToken)
        {
            query = ApplyQuery(request, query);

            var totalCount = await query.CountAsync(cancellationToken);
            var requests = await query
                .OrderByDescending(cardRequest => cardRequest.CreatedAtUtc)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToListAsync(cancellationToken);

            return new PagedResult<CardRequestResponse>
            {
                Items = requests.Select(ToRequestResponse).ToList(),
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        private IQueryable<CardRequest> BaseRequestQuery()
        {
            return dbContext.CardRequests
                .AsNoTracking()
                .Include(cardRequest => cardRequest.User)
                .Include(cardRequest => cardRequest.ApprovedAccount)
                .Include(cardRequest => cardRequest.ApprovedCard)
                .Include(cardRequest => cardRequest.Documents);
        }

        private static IQueryable<CardRequest> ApplyQuery(
            CardRequestQueryRequest request,
            IQueryable<CardRequest> query)
        {
            if (request.CustomerId.HasValue)
            {
                query = query.Where(cardRequest => cardRequest.UserId == request.CustomerId.Value);
            }

            if (request.Status.HasValue)
            {
                query = query.Where(cardRequest => cardRequest.Status == request.Status.Value);
            }

            if (request.DateFromUtc.HasValue)
            {
                var dateFrom = request.DateFromUtc.Value.Date;
                query = query.Where(cardRequest => cardRequest.CreatedAtUtc >= dateFrom);
            }

            if (request.DateToUtc.HasValue)
            {
                var dateTo = request.DateToUtc.Value.Date.AddDays(1);
                query = query.Where(cardRequest => cardRequest.CreatedAtUtc < dateTo);
            }

            if (!string.IsNullOrWhiteSpace(request.Search))
            {
                var search = request.Search.Trim();
                query = query.Where(cardRequest =>
                    cardRequest.CardholderName.Contains(search) ||
                    cardRequest.Currency.Contains(search) ||
                    cardRequest.DocumentNumber.Contains(search) ||
                    cardRequest.User.FirstName.Contains(search) ||
                    cardRequest.User.LastName.Contains(search) ||
                    cardRequest.User.Email.Contains(search));
            }

            return query;
        }

        private async Task<CardRequest> GetRequestForReviewAsync(
            Guid id,
            CancellationToken cancellationToken)
        {
            var cardRequest = await dbContext.CardRequests
                .Include(request => request.User)
                .Include(request => request.ApprovedAccount)
                .Include(request => request.ApprovedCard)
                .Include(request => request.Documents)
                .FirstOrDefaultAsync(request => request.Id == id, cancellationToken);

            return cardRequest ?? throw new NotFoundException("Zahtjev za karticu nije pronadjen.");
        }

        private async Task<string> GenerateAccountNumberAsync(CancellationToken cancellationToken)
        {
            string accountNumber;

            do
            {
                accountNumber = $"BA-{Random.Shared.Next(100000, 999999)}-CHECKING";
            }
            while (await dbContext.Accounts.AnyAsync(
                account => account.AccountNumber == accountNumber,
                cancellationToken));

            return accountNumber;
        }

        private async Task<string> GenerateCardNumberAsync(CancellationToken cancellationToken)
        {
            string cardNumber;

            do
            {
                cardNumber = $"4562{Random.Shared.NextInt64(100000000000, 999999999999)}";
            }
            while (await dbContext.BankCards.AnyAsync(
                card => card.CardNumber == cardNumber,
                cancellationToken));

            return cardNumber;
        }

        private static string GenerateCvv()
        {
            return Random.Shared.Next(1000, 9999).ToString();
        }

        private static CardResponse ToCardResponse(BankCard card)
        {
            return new CardResponse
            {
                Id = card.Id,
                AccountId = card.AccountId,
                AccountNumber = card.Account.AccountNumber,
                CardNumber = string.Empty,
                MaskedCardNumber = MaskCardNumber(card.CardNumber),
                CardholderName = card.CardholderName,
                Cvv = string.Empty,
                ExpiryDate = card.ExpiryDate,
                Brand = card.Brand,
                Status = card.Status,
                Balance = card.Account.Balance,
                Currency = card.Account.Currency,
                CreatedAtUtc = card.CreatedAtUtc
            };
        }

        private static CardRequestResponse ToRequestResponse(CardRequest request)
        {
            return new CardRequestResponse
            {
                Id = request.Id,
                UserId = request.UserId,
                CustomerName = $"{request.User.FirstName} {request.User.LastName}".Trim(),
                CustomerEmail = request.User.Email,
                CardholderName = request.CardholderName,
                Currency = request.Currency,
                DocumentNumber = request.DocumentNumber,
                DeliveryAddress = request.DeliveryAddress,
                Note = request.Note,
                Status = request.Status,
                AdminNote = request.AdminNote,
                DocumentsRequestNote = request.DocumentsRequestNote,
                DocumentsRequestedAtUtc = request.DocumentsRequestedAtUtc,
                ApprovedAccountId = request.ApprovedAccountId,
                ApprovedCardId = request.ApprovedCardId,
                ApprovedAccountNumber = request.ApprovedAccount?.AccountNumber,
                ApprovedMaskedCardNumber = request.ApprovedCard == null
                    ? null
                    : MaskCardNumber(request.ApprovedCard.CardNumber),
                ApprovedCardExpiryDate = request.ApprovedCard?.ExpiryDate,
                ApprovedCardStatus = request.ApprovedCard?.Status,
                ApprovedCardBrand = request.ApprovedCard?.Brand,
                CreatedAtUtc = request.CreatedAtUtc,
                ReviewedAtUtc = request.ReviewedAtUtc,
                Documents = request.Documents
                    .OrderByDescending(document => document.UploadedAtUtc)
                    .Select(ToDocumentResponse)
                    .ToList()
            };
        }

        private static CardRequestDocumentResponse ToDocumentResponse(CardRequestDocument document)
        {
            return new CardRequestDocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                SizeBytes = document.SizeBytes,
                UploadedAtUtc = document.UploadedAtUtc
            };
        }

        private static bool CanReview(CardRequestStatus status)
        {
            return status is CardRequestStatus.Pending or CardRequestStatus.DocumentsRequested;
        }

        private static string MaskCardNumber(string cardNumber)
        {
            if (cardNumber.Length < 4)
            {
                return "****";
            }

            return $"**** **** **** {cardNumber[^4..]}";
        }
    }
}
