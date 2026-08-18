using BankingApp.Application.Cards;
using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Interfaces
{
    public interface ICardService
    {
        Task<IReadOnlyCollection<CardResponse>> GetMyCardsAsync(
            CancellationToken cancellationToken = default);

        Task<CardSensitiveDataResponse> GetSensitiveDataAsync(
            Guid id,
            CancellationToken cancellationToken = default);

        Task<CardResponse> SetFrozenAsync(
            Guid id,
            bool frozen,
            CancellationToken cancellationToken = default);

        Task<CardRequestResponse> CreateRequestAsync(
            CardRequestCreateRequest request,
            CancellationToken cancellationToken = default);

        Task<PagedResult<CardRequestResponse>> GetMyRequestsAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default);

        Task<PagedResult<CardRequestResponse>> GetRequestsAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestSummaryResponse> GetRequestSummaryAsync(
            CardRequestQueryRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestResponse> ApproveAsync(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestResponse> RejectAsync(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestResponse> RequestDocumentsAsync(
            Guid id,
            CardRequestDocumentsRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestResponse> UploadDocumentAsync(
            Guid id,
            CardRequestDocumentUploadRequest request,
            CancellationToken cancellationToken = default);

        Task<CardRequestDocumentDownloadResponse> DownloadDocumentAsync(
            Guid requestId,
            Guid documentId,
            CancellationToken cancellationToken = default);
    }
}
