using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Transactions;

namespace BankingApp.Application.Interfaces
{
    public interface ITransactionService
    {
        Task<PagedResult<TransactionResponse>> GetAsync(TransactionQueryRequest request, CancellationToken cancellationToken = default);

        Task<TransactionSummaryResponse> GetSummaryAsync(TransactionQueryRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

        Task<TransactionResponse> CreateAsync(TransactionCreateRequest request, CancellationToken cancellationToken = default);

        Task<MoneyTransferResponse> SendMoneyAsync(MoneyTransferRequest request, CancellationToken cancellationToken = default);

        Task<TransactionResponse> UpdateAsync(Guid id, TransactionUpdateRequest request, CancellationToken cancellationToken = default);

        Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
    }
}
