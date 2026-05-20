using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Customers;

namespace BankingApp.Application.Interfaces
{
    public interface IAdminCustomerService
    {
        Task<PagedResult<CustomerResponse>> GetAsync(
            CustomerQueryRequest request,
            CancellationToken cancellationToken = default);

        Task<CustomerSummaryResponse> GetSummaryAsync(
            CustomerQueryRequest request,
            CancellationToken cancellationToken = default);

        Task<CustomerResponse> UpdateAsync(
            Guid id,
            CustomerUpdateRequest request,
            CancellationToken cancellationToken = default);

        Task<CustomerResponse> UpdateStatusAsync(
            Guid id,
            CustomerStatusUpdateRequest request,
            CancellationToken cancellationToken = default);

        Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
    }
}
