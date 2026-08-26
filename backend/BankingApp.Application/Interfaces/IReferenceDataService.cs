using BankingApp.Application.ReferenceData;
using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Interfaces;

public interface IReferenceDataService
{
    Task<PagedResult<ReferenceDataResponse>> GetAsync(string type, ReferenceDataQuery query, bool activeOnly, CancellationToken cancellationToken = default);
    Task<ReferenceDataResponse> CreateAsync(string type, ReferenceDataWriteRequest request, CancellationToken cancellationToken = default);
    Task<ReferenceDataResponse> UpdateAsync(string type, Guid id, ReferenceDataWriteRequest request, CancellationToken cancellationToken = default);
    Task<ReferenceDataResponse> SetActiveAsync(string type, Guid id, bool isActive, CancellationToken cancellationToken = default);
}
