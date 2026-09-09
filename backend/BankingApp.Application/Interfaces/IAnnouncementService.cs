using BankingApp.Application.Announcements;
using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Interfaces;

public interface IAnnouncementService
{
    Task<PagedResult<AnnouncementResponse>> GetPublishedAsync(AnnouncementQuery query, CancellationToken token = default);
    Task<PagedResult<AnnouncementResponse>> GetAdminAsync(AnnouncementQuery query, CancellationToken token = default);
    Task<AnnouncementResponse> GetAdminByIdAsync(Guid id, CancellationToken token = default);
    Task<AnnouncementResponse> CreateAsync(AnnouncementWriteRequest request, CancellationToken token = default);
    Task<AnnouncementResponse> UpdateAsync(Guid id, AnnouncementWriteRequest request, CancellationToken token = default);
}
