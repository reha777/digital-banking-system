using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Settings;
using BankingApp.Application.AuditLogs;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public class AdminSettingsService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUser,
    IPasswordHasher passwordHasher,
    IAuditLogService? auditLogService = null) : IAdminSettingsService
{
    public const int MaximumProfilePhotoSizeBytes = 2 * 1024 * 1024;
    public async Task<AdminSettingsResponse> GetAsync(CancellationToken cancellationToken = default)
    {
        var system = await GetOrCreateSystemAsync(cancellationToken);
        var preferences = await GetOrCreatePreferencesAsync(cancellationToken);
        var user = await GetUserAsync(cancellationToken);
        return new(ToSystemResponse(system), ToPreferencesResponse(preferences), ToProfileResponse(user));
    }

    public async Task<SystemSettingsResponse> UpdateSystemAsync(UpdateSystemSettingsRequest request, CancellationToken cancellationToken = default)
    {
        if (request.AutoLogoutWarningMinutes >= request.SessionTimeoutMinutes)
            throw new BusinessException("Upozorenje za odjavu mora biti prije isteka sesije.");
        var value = await GetOrCreateSystemAsync(cancellationToken);
        value.SystemName = request.SystemName.Trim();
        value.SystemShortName = request.SystemShortName.Trim();
        value.CompanyName = request.CompanyName.Trim();
        value.CompanyEmail = request.CompanyEmail.Trim();
        value.CompanyPhone = request.CompanyPhone.Trim();
        value.Timezone = request.Timezone.Trim();
        value.SessionTimeoutMinutes = request.SessionTimeoutMinutes;
        value.AutoLogoutWarningMinutes = request.AutoLogoutWarningMinutes;
        value.EnableDataCaching = request.EnableDataCaching;
        value.UpdatedAtUtc = DateTime.UtcNow;
        value.UpdatedByUserId = currentUser.UserId;
        await AuditAsync(AuditLogActions.AdminSettingsUpdated, AuditEntityTypes.AdminSettings,
            value.Id.ToString(), "Administrative system settings updated.", cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToSystemResponse(value);
    }

    public async Task<AdminPreferencesResponse> UpdatePreferencesAsync(UpdateAdminPreferencesRequest request, CancellationToken cancellationToken = default)
    {
        ValidateChoice(request.ThemeMode, ["light", "dark", "system"], "Theme mode");
        ValidateChoice(request.SidebarStyle, ["compact", "expanded"], "Sidebar style");
        ValidateChoice(request.DateFormat, ["DD.MM.YYYY", "DD/MM/YYYY", "MM/DD/YYYY", "YYYY-MM-DD"], "Date format");
        ValidateChoice(request.TimeFormat, ["24h", "12h"], "Time format");
        ValidateChoice(request.FirstDayOfWeek, ["monday", "sunday"], "First day of week");
        ValidateChoice(request.NumberFormat, ["1,234.56", "1.234,56"], "Number format");
        if (request.DefaultItemsPerPage is not (10 or 20 or 50))
            throw new BusinessException("Broj redova mora biti 10, 20 ili 50.");
        var value = await GetOrCreatePreferencesAsync(cancellationToken);
        value.ThemeMode = request.ThemeMode;
        value.SidebarStyle = request.SidebarStyle;
        value.DateFormat = request.DateFormat;
        value.TimeFormat = request.TimeFormat;
        value.FirstDayOfWeek = request.FirstDayOfWeek;
        value.NumberFormat = request.NumberFormat;
        value.Timezone = request.Timezone.Trim();
        value.DefaultItemsPerPage = request.DefaultItemsPerPage;
        value.UpdatedAtUtc = DateTime.UtcNow;
        await AuditAsync(AuditLogActions.AdminSettingsUpdated, AuditEntityTypes.AdminSettings,
            value.Id.ToString(), "Administrative preferences updated.", cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToPreferencesResponse(value);
    }

    public async Task<AdminProfileResponse> UpdateProfileAsync(UpdateAdminProfileRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetUserAsync(cancellationToken);
        user.FirstName = request.FirstName.Trim();
        user.LastName = request.LastName.Trim();
        user.PhoneNumber = request.PhoneNumber.Trim();
        await AuditAsync(AuditLogActions.AdminProfileUpdated, AuditEntityTypes.AdminProfile,
            user.Id.ToString(), "Administrator profile updated.", cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToProfileResponse(user);
    }

    public async Task<AdminProfileResponse> UploadProfilePhotoAsync(
        AdminProfilePhotoUploadRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.Content.Length == 0)
            throw new BusinessException("Profile photo cannot be empty.");
        if (request.Content.Length > MaximumProfilePhotoSizeBytes)
            throw new BusinessException("Profile photo cannot be larger than 2 MB.");
        if (!HasValidImageSignature(request.Content, request.ContentType))
            throw new BusinessException("The selected file is not a valid JPG or PNG image.");

        var user = await GetUserAsync(cancellationToken);
        user.ProfilePhoto = request.Content;
        user.ProfilePhotoContentType = request.ContentType;
        user.ProfilePhotoUpdatedAtUtc = DateTime.UtcNow;
        await AuditAsync(AuditLogActions.AdminProfileUpdated, AuditEntityTypes.AdminProfile,
            user.Id.ToString(), "Administrator profile photo updated.", cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToProfileResponse(user);
    }

    public async Task<AdminProfilePhotoResponse> GetProfilePhotoAsync(
        CancellationToken cancellationToken = default)
    {
        var user = await GetUserAsync(cancellationToken);
        if (user.ProfilePhoto is not { Length: > 0 } || string.IsNullOrWhiteSpace(user.ProfilePhotoContentType))
            throw new NotFoundException("Profile photo was not found.");
        return new AdminProfilePhotoResponse(user.ProfilePhoto, user.ProfilePhotoContentType);
    }

    public async Task<AdminProfileResponse> DeleteProfilePhotoAsync(
        CancellationToken cancellationToken = default)
    {
        var user = await GetUserAsync(cancellationToken);
        user.ProfilePhoto = null;
        user.ProfilePhotoContentType = null;
        user.ProfilePhotoUpdatedAtUtc = null;
        await AuditAsync(AuditLogActions.AdminProfileUpdated, AuditEntityTypes.AdminProfile,
            user.Id.ToString(), "Administrator profile photo removed.", cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToProfileResponse(user);
    }

    public async Task ChangePasswordAsync(ChangeAdminPasswordRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetUserAsync(cancellationToken);
        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
            throw new BusinessException("Trenutna lozinka nije ispravna.");
        user.PasswordHash = passwordHasher.Hash(request.NewPassword);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<SystemSettings> GetOrCreateSystemAsync(CancellationToken cancellationToken)
    {
        var value = await dbContext.SystemSettings.SingleOrDefaultAsync(cancellationToken);
        if (value != null) return value;
        value = new SystemSettings { CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow };
        dbContext.SystemSettings.Add(value);
        await dbContext.SaveChangesAsync(cancellationToken);
        return value;
    }

    private async Task<AdminUserPreferences> GetOrCreatePreferencesAsync(CancellationToken cancellationToken)
    {
        var value = await dbContext.AdminUserPreferences.SingleOrDefaultAsync(x => x.UserId == currentUser.UserId, cancellationToken);
        if (value != null) return value;
        value = new AdminUserPreferences { Id = Guid.NewGuid(), UserId = currentUser.UserId, UpdatedAtUtc = DateTime.UtcNow };
        dbContext.AdminUserPreferences.Add(value);
        await dbContext.SaveChangesAsync(cancellationToken);
        return value;
    }

    private async Task<User> GetUserAsync(CancellationToken cancellationToken) =>
        await dbContext.Users.SingleOrDefaultAsync(x => x.Id == currentUser.UserId, cancellationToken)
        ?? throw new NotFoundException("Administrator nije pronadjen.");

    private static void ValidateChoice(string value, string[] allowed, string name)
    {
        if (!allowed.Contains(value)) throw new BusinessException($"{name} nije validan.");
    }
    private Task AuditAsync(string action, string entityType, string entityId, string description, CancellationToken token) =>
        auditLogService?.RecordAsync(new AuditLogRecordRequest
        {
            Action = action, EntityType = entityType, EntityId = entityId, Description = description
        }, token) ?? Task.CompletedTask;
    private static SystemSettingsResponse ToSystemResponse(SystemSettings x) => new(x.SystemName, x.SystemShortName, x.CompanyName, x.CompanyEmail, x.CompanyPhone, x.Timezone, x.SessionTimeoutMinutes, x.AutoLogoutWarningMinutes, x.EnableDataCaching, x.UpdatedAtUtc);
    private static AdminPreferencesResponse ToPreferencesResponse(AdminUserPreferences x) => new(x.ThemeMode, x.SidebarStyle, x.DateFormat, x.TimeFormat, x.FirstDayOfWeek, x.NumberFormat, x.DefaultItemsPerPage, x.Timezone);
    private static bool HasValidImageSignature(byte[] content, string contentType) =>
        contentType switch
        {
            "image/jpeg" => content.Length >= 3 && content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF,
            "image/png" => content.Length >= 8 && content.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            _ => false
        };
    private static AdminProfileResponse ToProfileResponse(User x) => new(
        x.FirstName, x.LastName, x.Email, x.PhoneNumber,
        x.ProfilePhoto is { Length: > 0 }, x.ProfilePhotoUpdatedAtUtc);
}
