using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Loans;

namespace BankingApp.Application.Interfaces;

public interface IAdminLoanService
{
    Task<PagedResult<AdminLoanApplicationListItemResponse>> GetApplicationsAsync(
        AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken = default);

    Task<AdminLoanSummaryResponse> GetSummaryAsync(
        AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken = default);

    Task<AdminLoanApplicationDetailsResponse> GetApplicationDetailsAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    Task<AdminLoanApplicationDetailsResponse> ApproveApplicationAsync(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken = default);

    Task<AdminLoanApplicationDetailsResponse> RejectApplicationAsync(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken = default);

    Task<PagedResult<AdminLoanListItemResponse>> GetLoansAsync(AdminLoanQueryRequest request, CancellationToken cancellationToken = default);
    Task<AdminLoanDetailsResponse> GetLoanDetailsAsync(Guid id, CancellationToken cancellationToken = default);
    Task<AdminLoansOverviewResponse> GetLoansOverviewAsync(CancellationToken cancellationToken = default);
    Task<AdminLoanApplicationDetailsResponse> RequestDocumentAsync(Guid id, LoanDocumentRequest request, CancellationToken cancellationToken = default);
    Task<IReadOnlyCollection<LoanDocumentResponse>> GetDocumentsAsync(Guid applicationId, CancellationToken cancellationToken = default);
    Task<LoanDocumentDownloadResponse> DownloadDocumentAsync(Guid applicationId, Guid documentId, CancellationToken cancellationToken = default);
}
