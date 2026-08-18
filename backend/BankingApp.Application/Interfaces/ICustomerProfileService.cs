using BankingApp.Application.Profiles;

namespace BankingApp.Application.Interfaces;

public interface ICustomerProfileService
{
    Task<CustomerProfileResponse> GetAsync(CancellationToken cancellationToken = default);
    Task<CustomerProfileResponse> UpdateAsync(UpdateCustomerProfileRequest request, CancellationToken cancellationToken = default);
    Task ChangePasswordAsync(ChangeCustomerPasswordRequest request, CancellationToken cancellationToken = default);
    Task<CustomerProfileResponse> UploadPhotoAsync(CustomerProfilePhotoUploadRequest request, CancellationToken cancellationToken = default);
    Task<CustomerProfilePhotoResponse> GetPhotoAsync(CancellationToken cancellationToken = default);
}
