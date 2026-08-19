using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Transactions;

namespace BankingApp.Application.Interfaces
{
    public interface ITransactionService
    {
        Task<PagedResult<TransactionResponse>> GetAsync(TransactionQueryRequest request, CancellationToken cancellationToken = default);

        Task<TransactionSummaryResponse> GetSummaryAsync(TransactionQueryRequest request, CancellationToken cancellationToken = default);
        Task<TransactionStatisticsResponse> GetStatisticsAsync(TransactionStatisticsQuery request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

        Task<TransactionResponse> CreateAsync(TransactionCreateRequest request, CancellationToken cancellationToken = default);

        Task<MoneyTransferResponse> SendMoneyAsync(MoneyTransferRequest request, CancellationToken cancellationToken = default);

        Task<MoneyTransferQuoteResponse> QuoteAsync(MoneyTransferQuoteRequest request, CancellationToken cancellationToken = default);

        Task<MoneyTransferQuoteResponse> QuoteInternalTransferAsync(InternalTransferQuoteRequest request, CancellationToken cancellationToken = default);

        Task<MoneyTransferResponse> InternalTransferAsync(InternalTransferRequest request, CancellationToken cancellationToken = default);

        Task<IReadOnlyCollection<RecentRecipientResponse>> GetRecentRecipientsAsync(CancellationToken cancellationToken = default);

        Task<RecentRecipientResponse> LookupRecipientAsync(string accountNumber, CancellationToken cancellationToken = default);

        Task<TransactionResponse> UpdateAsync(Guid id, TransactionUpdateRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> ApproveReviewAsync(Guid id, TransactionReviewRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> RejectReviewAsync(Guid id, TransactionReviewRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> RequestDocumentsAsync(Guid id, TransactionDocumentsRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> UploadDocumentAsync(Guid id, TransactionDocumentUploadRequest request, CancellationToken cancellationToken = default);

        Task<TransactionDocumentDownloadResponse> DownloadDocumentAsync(Guid transactionId, Guid documentId, CancellationToken cancellationToken = default);

        Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
    }
}
