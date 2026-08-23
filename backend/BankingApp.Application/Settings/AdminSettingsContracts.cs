using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Settings;

public record AdminSettingsResponse(
    SystemSettingsResponse System,
    AdminPreferencesResponse Preferences,
    AdminProfileResponse Profile);

public record SystemSettingsResponse(
    string SystemName, string SystemShortName, string CompanyName,
    string CompanyEmail, string CompanyPhone, string Timezone,
    int SessionTimeoutMinutes, int AutoLogoutWarningMinutes,
    bool EnableDataCaching, DateTime UpdatedAtUtc);

public record AdminPreferencesResponse(
    string ThemeMode, string SidebarStyle, string DateFormat,
    string TimeFormat, string FirstDayOfWeek, string NumberFormat,
    int DefaultItemsPerPage, string Timezone);

public record AdminProfileResponse(
    string FirstName, string LastName, string Email, string PhoneNumber,
    bool HasProfilePhoto, DateTime? ProfilePhotoUpdatedAtUtc);

public record AdminProfilePhotoResponse(byte[] Content, string ContentType);

public class AdminProfilePhotoUploadRequest
{
    public required byte[] Content { get; set; }
    public required string ContentType { get; set; }
}

public class UpdateSystemSettingsRequest
{
    [Required, StringLength(120)] public string SystemName { get; set; } = "";
    [Required, StringLength(20)] public string SystemShortName { get; set; } = "";
    [Required, StringLength(160)] public string CompanyName { get; set; } = "";
    [Required, EmailAddress, StringLength(256)] public string CompanyEmail { get; set; } = "";
    [Required, Phone, StringLength(30)] public string CompanyPhone { get; set; } = "";
    [Required, StringLength(80)] public string Timezone { get; set; } = "";
    [Range(5, 480)] public int SessionTimeoutMinutes { get; set; }
    [Range(1, 60)] public int AutoLogoutWarningMinutes { get; set; }
    public bool EnableDataCaching { get; set; }
}

public class UpdateAdminPreferencesRequest
{
    [Required] public string ThemeMode { get; set; } = "system";
    [Required] public string SidebarStyle { get; set; } = "expanded";
    [Required] public string DateFormat { get; set; } = "DD.MM.YYYY";
    [Required] public string TimeFormat { get; set; } = "24h";
    [Required] public string FirstDayOfWeek { get; set; } = "monday";
    [Required] public string NumberFormat { get; set; } = "1,234.56";
    [Required, StringLength(80)] public string Timezone { get; set; } = "Europe/Sarajevo";
    [Range(10, 50)] public int DefaultItemsPerPage { get; set; }
}

public class UpdateAdminProfileRequest
{
    [Required, StringLength(100)] public string FirstName { get; set; } = "";
    [Required, StringLength(100)] public string LastName { get; set; } = "";
    [Required, Phone, StringLength(30)] public string PhoneNumber { get; set; } = "";
}

public class ChangeAdminPasswordRequest
{
    [Required] public string CurrentPassword { get; set; } = "";
    [Required, MinLength(8), MaxLength(100)] public string NewPassword { get; set; } = "";
}
