using BankingApp.Application.Settings;

namespace BankingApp.Application.Interfaces;

public interface IAdminSettingsService
{
    Task<AdminSettingsResponse> GetAsync(CancellationToken cancellationToken = default);
    Task<SystemSettingsResponse> UpdateSystemAsync(UpdateSystemSettingsRequest request, CancellationToken cancellationToken = default);
    Task<AdminPreferencesResponse> UpdatePreferencesAsync(UpdateAdminPreferencesRequest request, CancellationToken cancellationToken = default);
    Task<AdminProfileResponse> UpdateProfileAsync(UpdateAdminProfileRequest request, CancellationToken cancellationToken = default);
    Task ChangePasswordAsync(ChangeAdminPasswordRequest request, CancellationToken cancellationToken = default);
}
