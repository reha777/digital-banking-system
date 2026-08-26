using System.ComponentModel.DataAnnotations;
using BankingApp.Application.Auth;

namespace BankingApp.Application.Profiles;

public record CustomerProfileResponse(
    Guid Id,
    string FirstName,
    string LastName,
    string Email,
    string PhoneNumber,
    string Role,
    bool HasProfilePhoto,
    DateTime? ProfilePhotoUpdatedAtUtc);

public class CustomerProfilePhotoUploadRequest
{
    public string ContentType { get; set; } = string.Empty;
    public byte[] Content { get; set; } = [];
}

public record CustomerProfilePhotoResponse(byte[] Content, string ContentType);

public class UpdateCustomerProfileRequest
{
    [Required, StringLength(100, MinimumLength = 1)]
    public string FirstName { get; set; } = string.Empty;

    [Required, StringLength(100, MinimumLength = 1)]
    public string LastName { get; set; } = string.Empty;

    [Required, Phone, StringLength(30)]
    public string PhoneNumber { get; set; } = string.Empty;
}

public class ChangeCustomerPasswordRequest
{
    [Required]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, MinLength(PasswordPolicy.MinimumLength), MaxLength(100)]
    public string NewPassword { get; set; } = string.Empty;
}
