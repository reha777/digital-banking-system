using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Interfaces
{
    public interface IAccountService
    {
        Task<PagedResult<AccountResponse>> GetAsync(AccountQueryRequest request, CancellationToken cancellationToken = default);

        Task<AccountBalanceSummaryResponse> GetBalanceSummaryAsync(CancellationToken cancellationToken = default);

        Task<AccountResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

        Task<AccountResponse> CloseAsync(Guid id, CancellationToken cancellationToken = default);
    }
}
