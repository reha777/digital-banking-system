using BankingApp.Application.AccountTypes;

namespace BankingApp.Application.Interfaces;

public interface IAccountTypeService
{
    Task<IReadOnlyList<AccountTypeResponse>> GetActiveAsync(CancellationToken token = default);
    Task<IReadOnlyList<AccountTypeResponse>> GetAdminAsync(CancellationToken token = default);
    Task<AccountTypeResponse> GetAdminByIdAsync(Guid id, CancellationToken token = default);
    Task<AccountTypeResponse> CreateAsync(AccountTypeCreateRequest request, CancellationToken token = default);
    Task<AccountTypeResponse> UpdateAsync(Guid id, AccountTypeUpdateRequest request, CancellationToken token = default);
    Task<AccountTypeResponse> SetActiveAsync(Guid id, bool active, CancellationToken token = default);
}
