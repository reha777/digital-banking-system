using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Reports;
namespace BankingApp.Application.Interfaces;
public interface IAdminReportService
{
    Task<ReportJobResponse> RequestTransactionAsync(TransactionReportRequest request, CancellationToken token = default);
    Task<ReportJobResponse> RequestLoanAsync(LoanPortfolioReportRequest request, CancellationToken token = default);
    Task<ReportJobResponse> GetAsync(Guid id, CancellationToken token = default);
    Task<PagedResult<ReportJobResponse>> ListAsync(ReportJobQuery query, CancellationToken token = default);
    Task<ReportFileResponse> DownloadAsync(Guid id, CancellationToken token = default);
}
