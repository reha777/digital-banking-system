using BankingApp.Application.Cards;
using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Services;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
using System.Security.Cryptography;

namespace BankingApp.Infrastructure.Services
{
    public class CardService(
        BankingAppDbContext dbContext,
        ICurrentUserService currentUserService,
        IAuditLogService? auditLogService = null,
        IFileValidationService? fileValidationService = null,
        INotificationWriter? notificationWriter = null) : ICardService
    {
        public async Task<PagedResult<CardResponse>> GetMyCardsAsync(
            PagedRequest request,
            CancellationToken cancellationToken = default)
        {
            var query = dbContext.BankCards
                .AsNoTracking()
                .Include(card => card.Account)
                .Where(card => card.Account.UserId == currentUserService.UserId);
            var total = await query.CountAsync(cancellationToken);
            var cards = await query
                .OrderByDescending(card => card.CreatedAtUtc)
                .ThenBy(card => card.Id)
                .Skip((request.Page - 1) * request.PageSize)
                .Take(request.PageSize)
                .ToListAsync(cancellationToken);

            return new PagedResult<CardResponse>
            {
                Items = cards.Select(ToCardResponse).ToList(),
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = total
            };
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

            // The CVV is intentionally not returned here. It is not persisted and
            // is only ever available once, in the issue result at approval time.
            return new CardSensitiveDataResponse
            {
                Id = card.Id,
                CardNumber = card.CardNumber,
                ExpiryDate = card.ExpiryDate
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
            if (!frozen && card.Account.Status != AccountStatus.Active)
                throw new BusinessException("Kartica zatvorenog racuna ne moze biti aktivirana.");

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

            if (!SupportedCurrencies.IsSupported(request.Currency))
                throw new BusinessException("Valuta nije podrzana. Dozvoljene valute su USD, EUR i BAM.");
            var cardRequest = new CardRequest
            {
                Id = Guid.NewGuid(),
                UserId = currentUserService.UserId,
                CardholderName = request.CardholderName.Trim(),
                Currency = SupportedCurrencies.Normalize(request.Currency),
                DocumentNumber = request.DocumentNumber.Trim(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                Note = request.Note?.Trim() ?? string.Empty,
                Status = CardRequestStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.CardRequests.Add(cardRequest);
            if (notificationWriter is not null)
                await notificationWriter.AddForAdminsAsync(new NotificationCreate(Guid.Empty, NotificationType.NewCardRequest, "New card request", "A customer submitted a new card request.", NotificationEntityTypes.CardRequest, cardRequest.Id), cancellationToken);
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

        public async Task<AdminIssuedCardResponse> GetIssuedCardAsync(
            Guid id, CancellationToken cancellationToken = default)
        {
            var card = await AdminCardQuery().SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
                ?? throw new NotFoundException("Kartica nije pronadjena.");
            return ToAdminIssuedCardResponse(card);
        }

        public async Task<AdminIssuedCardResponse> SetAdminCardStatusAsync(
            Guid id, bool blocked, CancellationToken cancellationToken = default)
        {
            var card = await AdminCardQuery(false).SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
                ?? throw new NotFoundException("Kartica nije pronadjena.");
            if (card.Status == CardStatus.Expired)
                throw new BusinessException("Istekla kartica ne moze promijeniti status.");
            if (!blocked && card.Account.Status != AccountStatus.Active)
                throw new BusinessException("Kartica zatvorenog racuna ne moze biti aktivirana.");
            var target = blocked ? CardStatus.Blocked : CardStatus.Active;
            if (card.Status == target) return ToAdminIssuedCardResponse(card);
            var oldStatus = card.Status;
            card.Status = target;
            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = blocked ? AuditLogActions.CardBlockedByAdmin : AuditLogActions.CardUnblockedByAdmin,
                    EntityType = AuditEntityTypes.Card, EntityId = card.Id.ToString(),
                    Description = $"{(blocked ? "Blocked" : "Unblocked")} card ending {card.CardNumber[^4..]}.",
                    OldValue = oldStatus.ToString(), NewValue = target.ToString()
                }, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            return ToAdminIssuedCardResponse(card);
        }

        private IQueryable<BankCard> AdminCardQuery(bool noTracking = true)
        {
            var query = dbContext.BankCards.Include(value => value.Account)
                .ThenInclude(value => value.User).AsQueryable();
            return noTracking ? query.AsNoTracking() : query;
        }

        private static AdminIssuedCardResponse ToAdminIssuedCardResponse(BankCard card) => new()
        {
            Id = card.Id, CustomerId = card.Account.UserId,
            CustomerName = $"{card.Account.User.FirstName} {card.Account.User.LastName}".Trim(),
            CustomerEmail = card.Account.User.Email,
            MaskedCardNumber = "**** **** **** " + card.CardNumber[^4..],
            CardholderName = card.CardholderName, Brand = card.Brand,
            ExpiryDate = card.ExpiryDate, Status = card.Status, AccountId = card.AccountId,
            AccountNumber = card.Account.AccountNumber, Currency = card.Account.Currency,
            CreatedAtUtc = card.CreatedAtUtc
        };

        public async Task<CardRequestResponse> ApproveAsync(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken = default)
        {
            var cardRequest = await GetRequestForReviewAsync(id, cancellationToken);

            // Everything below revalidates the current state of the system. The request
            // being valid when it was submitted is not enough to justify issuing an
            // account and a card now.
            if (!CanReview(cardRequest.Status))
            {
                throw new BusinessException("Samo zahtjev koji ceka odobrenje moze biti odobren.");
            }

            // GetRequestForReviewAsync loaded the customer as part of this call, so this
            // is their status right now, not at request time.
            var customer = cardRequest.User;
            if (customer.Role != AppRoles.Customer || customer.IsDeleted ||
                customer.Status != CustomerStatus.Active)
            {
                throw new BusinessException("Customer is no longer active, so the card request cannot be approved.");
            }

            if (cardRequest.ApprovedAccountId is not null || cardRequest.ApprovedCardId is not null)
            {
                throw new BusinessException("Zahtjev za karticu vec ima izdan racun i karticu.");
            }

            if (!SupportedCurrencies.IsSupported(cardRequest.Currency))
                throw new BusinessException("Valuta zahtjeva vise nije podrzana.");

            var accountId = SecureIdentifierGenerator.NewGuid();
            // Item 8: the CHECKING type is reference data and may have been deactivated
            // since the request was created, so it is re-read and rechecked here.
            var accountType = await dbContext.AccountTypeDefinitions.SingleOrDefaultAsync(
                value => value.Code == BankingApp.Domain.Constants.AccountTypeCodes.Checking && value.IsActive,
                cancellationToken) ?? throw new BusinessException("Active CHECKING account type is not configured.");
            var account = new Account
            {
                Id = accountId,
                UserId = cardRequest.UserId,
                AccountNumber = AccountNumberGenerator.Create(accountId, BankingApp.Domain.Constants.AccountTypeCodes.Checking),
                AccountTypeId = accountType.Id,
                AccountTypeDefinition = accountType,
                Status = AccountStatus.Active,
                Balance = 0,
                Currency = cardRequest.Currency,
                CreatedAtUtc = DateTime.UtcNow
            };

            var card = new BankCard
            {
                Id = SecureIdentifierGenerator.NewGuid(),
                AccountId = account.Id,
                CardNumber = await GenerateCardNumberAsync(cancellationToken),
                CardholderName = cardRequest.CardholderName,
                ExpiryDate = DateTime.UtcNow.Date.AddYears(4),
                Brand = CardBrand.Mastercard,
                Status = CardStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };

            // Generated for the one-time issue result only: it is never written to
            // the card entity, the audit log, the notification or any log.
            var oneTimeCvv = GenerateCvv();

            cardRequest.Status = CardRequestStatus.Approved;
            cardRequest.AdminNote = request.AdminNote?.Trim();
            cardRequest.ApprovedAccountId = account.Id;
            cardRequest.ApprovedCardId = card.Id;
            cardRequest.ReviewedAtUtc = DateTime.UtcNow;
            cardRequest.ReviewedByUserId = currentUserService.UserId;

            dbContext.Accounts.Add(account);
            dbContext.BankCards.Add(card);
            if (notificationWriter is not null)
                await notificationWriter.AddAsync(new NotificationCreate(cardRequest.UserId, NotificationType.CardRequestApproved, "Card request approved", "Your card request was approved.", NotificationEntityTypes.CardRequest, cardRequest.Id), cancellationToken);
            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardRequestApproved,
                    EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(),
                    Description = "Card request approved.",
                    Reason = cardRequest.AdminNote
                }, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);

            cardRequest.ApprovedAccount = account;
            cardRequest.ApprovedCard = card;

            var response = ToRequestResponse(cardRequest);
            await PopulateDocumentsAsync([response], cancellationToken);
            response.IssuedCard = new CardIssueResult
            {
                CardId = card.Id,
                CardNumber = card.CardNumber,
                ExpiryMonth = card.ExpiryDate.Month,
                ExpiryYear = card.ExpiryDate.Year,
                OneTimeCvv = oneTimeCvv
            };
            return response;
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
            if (notificationWriter is not null)
                await notificationWriter.AddAsync(new NotificationCreate(cardRequest.UserId, NotificationType.CardRequestRejected, "Card request rejected", "Your card request was rejected. Open the request for details.", NotificationEntityTypes.CardRequest, cardRequest.Id), cancellationToken);

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardRequestRejected,
                    EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(),
                    Description = "Card request rejected.",
                    Reason = cardRequest.AdminNote
                }, cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);

            var rejectResponse = ToRequestResponse(cardRequest);
            await PopulateDocumentsAsync([rejectResponse], cancellationToken);
            return rejectResponse;
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
            if (notificationWriter is not null)
                await notificationWriter.AddAsync(new NotificationCreate(cardRequest.UserId, NotificationType.CardDocumentsRequested, "Card documents requested", "Additional documents are required for your card request.", NotificationEntityTypes.CardRequest, cardRequest.Id), cancellationToken);

            if (auditLogService is not null)
                await auditLogService.RecordAsync(new AuditLogRecordRequest
                {
                    Action = AuditLogActions.CardDocumentsRequested,
                    EntityType = AuditEntityTypes.CardRequest,
                    EntityId = id.ToString(),
                    Description = "Card request documents requested.",
                    Reason = cardRequest.DocumentsRequestNote
                }, cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);

            var documentsResponse = ToRequestResponse(cardRequest);
            await PopulateDocumentsAsync([documentsResponse], cancellationToken);
            return documentsResponse;
        }

        public async Task<CardRequestResponse> UploadDocumentAsync(
            Guid id,
            CardRequestDocumentUploadRequest request,
            CancellationToken cancellationToken = default)
        {
            var validatedFile = (fileValidationService ?? new FileValidationService()).ValidateDocument(request.FileName, request.ContentType, request.Content);

            var cardRequest = await dbContext.CardRequests
                .Include(item => item.User)
                .Include(item => item.ApprovedAccount)
                .Include(item => item.ApprovedCard)
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
                FileName = validatedFile.FileName,
                ContentType = validatedFile.ContentType,
                SizeBytes = request.Content.LongLength,
                Content = request.Content,
                UploadedAtUtc = DateTime.UtcNow
            };

            dbContext.CardRequestDocuments.Add(document);
            if (notificationWriter is not null)
                await notificationWriter.AddForAdminsAsync(new NotificationCreate(Guid.Empty, NotificationType.CardDocumentsUploaded, "Card documents uploaded", "A customer uploaded documents for a card request.", NotificationEntityTypes.CardRequest, cardRequest.Id), cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);

            var uploadResponse = ToRequestResponse(cardRequest);
            await PopulateDocumentsAsync([uploadResponse], cancellationToken);
            return uploadResponse;
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

            var items = requests.Select(ToRequestResponse).ToList();
            await PopulateDocumentsAsync(items, cancellationToken);

            return new PagedResult<CardRequestResponse>
            {
                Items = items,
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = totalCount
            };
        }

        /// <summary>
        /// Loads document metadata for the given card requests in a single projected
        /// query. The request queries deliberately do not Include the Documents
        /// navigation: <see cref="CardRequestDocument.Content"/> is a blob the metadata
        /// contract never exposes, so including it would pull every uploaded file's
        /// bytes out of the database for a paginated page.
        /// </summary>
        private async Task PopulateDocumentsAsync(
            IReadOnlyCollection<CardRequestResponse> responses,
            CancellationToken cancellationToken)
        {
            if (responses.Count == 0) return;
            var requestIds = responses.Select(response => response.Id).Distinct().ToList();

            var documents = await dbContext.CardRequestDocuments
                .AsNoTracking()
                .Where(document => requestIds.Contains(document.CardRequestId))
                .OrderByDescending(document => document.UploadedAtUtc)
                .Select(document => new
                {
                    document.CardRequestId,
                    Metadata = new CardRequestDocumentResponse
                    {
                        Id = document.Id,
                        FileName = document.FileName,
                        ContentType = document.ContentType,
                        SizeBytes = document.SizeBytes,
                        UploadedAtUtc = document.UploadedAtUtc
                    }
                })
                .ToListAsync(cancellationToken);

            var byRequest = documents
                .GroupBy(document => document.CardRequestId)
                .ToDictionary(
                    group => group.Key,
                    group => group.Select(document => document.Metadata).ToList());

            foreach (var response in responses)
            {
                response.Documents = byRequest.TryGetValue(response.Id, out var metadata)
                    ? metadata
                    : [];
            }
        }

        private IQueryable<CardRequest> BaseRequestQuery()
        {
            return dbContext.CardRequests
                .AsNoTracking()
                .Include(cardRequest => cardRequest.User)
                .Include(cardRequest => cardRequest.ApprovedAccount)
                .Include(cardRequest => cardRequest.ApprovedCard);
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
                .FirstOrDefaultAsync(request => request.Id == id, cancellationToken);

            return cardRequest ?? throw new NotFoundException("Zahtjev za karticu nije pronadjen.");
        }

        // Card numbers and security codes are drawn from the system CSPRNG
        // (RandomNumberGenerator), never from Random/Random.Shared.
        private async Task<string> GenerateCardNumberAsync(CancellationToken cancellationToken)
        {
            string cardNumber;

            do
            {
                // Unchanged format: the 4562 prefix plus 12 digits with a non-zero lead.
                cardNumber = $"4562{RandomNumberGenerator.GetInt32(1, 10)}{SecureIdentifierGenerator.NewDigits(11)}";
            }
            while (await dbContext.BankCards.AnyAsync(
                card => card.CardNumber == cardNumber,
                cancellationToken));

            return cardNumber;
        }

        /// <summary>
        /// Generates the one-time CVV handed back in <see cref="CardIssueResult"/>.
        /// The value is never persisted, audited, logged or notified.
        /// </summary>
        private static string GenerateCvv()
        {
            return RandomNumberGenerator.GetInt32(1000, 10000).ToString(CultureInfo.InvariantCulture);
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
