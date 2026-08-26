using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Settings;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;
using BankingApp.Api.Controllers;
using Microsoft.AspNetCore.Authorization;

namespace BankingApp.Infrastructure.Tests;

public class AdminSettingsProfilePhotoTests
{
    [Fact]
    public void Settings_routes_require_admin_authentication()
    {
        var authorize = Assert.Single(
            typeof(AdminSettingsController).GetCustomAttributes(typeof(AuthorizeAttribute), true)
                .Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, authorize.Roles);
    }

    [Fact]
    public async Task Update_then_get_returns_persisted_system_preferences_and_profile()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.UpdateSystemAsync(new UpdateSystemSettingsRequest
        {
            SystemName = "BankPick Admin",
            SystemShortName = "BPA",
            CompanyName = "BankPick",
            CompanyEmail = "support@bankpick.local",
            CompanyPhone = "+38761000001",
            Timezone = "Europe/Zagreb",
            SessionTimeoutMinutes = 45,
            AutoLogoutWarningMinutes = 5,
            EnableDataCaching = false
        });
        await fixture.Service.UpdatePreferencesAsync(new UpdateAdminPreferencesRequest
        {
            ThemeMode = "dark",
            SidebarStyle = "compact",
            DateFormat = "YYYY-MM-DD",
            TimeFormat = "12h",
            FirstDayOfWeek = "monday",
            NumberFormat = "1.234,56",
            DefaultItemsPerPage = 50,
            Timezone = "UTC"
        });
        await fixture.Service.UpdateProfileAsync(new UpdateAdminProfileRequest
        {
            FirstName = "Updated",
            LastName = "Administrator",
            PhoneNumber = "+38761111111"
        });

        var loaded = await fixture.Service.GetAsync();
        Assert.Equal("BankPick Admin", loaded.System.SystemName);
        Assert.Equal("BPA", loaded.System.SystemShortName);
        Assert.Equal(45, loaded.System.SessionTimeoutMinutes);
        Assert.Equal("dark", loaded.Preferences.ThemeMode);
        Assert.Equal("compact", loaded.Preferences.SidebarStyle);
        Assert.Equal("1.234,56", loaded.Preferences.NumberFormat);
        Assert.Equal("Updated", loaded.Profile.FirstName);
        Assert.Equal("admin@example.com", loaded.Profile.Email);
    }

    [Fact]
    public async Task Settings_validation_rejects_invalid_warning_and_preferences()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UpdateSystemAsync(
            new UpdateSystemSettingsRequest
            {
                SystemName = "Bank",
                SystemShortName = "B",
                CompanyName = "Bank",
                CompanyEmail = "admin@example.com",
                CompanyPhone = "+38761000000",
                Timezone = "UTC",
                SessionTimeoutMinutes = 10,
                AutoLogoutWarningMinutes = 10
            }));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UpdatePreferencesAsync(
            new UpdateAdminPreferencesRequest { ThemeMode = "invalid" }));
    }

    [Fact]
    public async Task Upload_read_and_delete_profile_photo_are_scoped_to_current_admin()
    {
        await using var fixture = await Fixture.CreateAsync();
        var png = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10, 1 };

        var uploaded = await fixture.Service.UploadProfilePhotoAsync(new AdminProfilePhotoUploadRequest
        {
            Content = png,
            ContentType = "image/png"
        });
        var stored = await fixture.Service.GetProfilePhotoAsync();

        Assert.True(uploaded.HasProfilePhoto);
        Assert.NotNull(uploaded.ProfilePhotoUpdatedAtUtc);
        Assert.Equal(png, stored.Content);
        Assert.Equal("image/png", stored.ContentType);

        var deleted = await fixture.Service.DeleteProfilePhotoAsync();
        Assert.False(deleted.HasProfilePhoto);
        Assert.Null(deleted.ProfilePhotoUpdatedAtUtc);
        await Assert.ThrowsAsync<NotFoundException>(() => fixture.Service.GetProfilePhotoAsync());
    }

    [Fact]
    public async Task Upload_rejects_spoofed_or_oversized_images()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UploadProfilePhotoAsync(
            new AdminProfilePhotoUploadRequest { Content = [1, 2, 3], ContentType = "image/png" }));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UploadProfilePhotoAsync(
            new AdminProfilePhotoUploadRequest
            {
                Content = new byte[AdminSettingsService.MaximumProfilePhotoSizeBytes + 1],
                ContentType = "image/png"
            }));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Guid adminId)
        {
            Db = db;
            Service = new AdminSettingsService(
                db,
                new CurrentUser(adminId),
                new Pbkdf2PasswordHasher());
        }

        public BankingAppDbContext Db { get; }
        public AdminSettingsService Service { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var options = new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            var db = new BankingAppDbContext(options);
            var id = Guid.NewGuid();
            db.Users.Add(new User
            {
                Id = id,
                FirstName = "Desktop",
                LastName = "Admin",
                Email = "admin@example.com",
                PhoneNumber = "+38761000000",
                PasswordHash = "hash",
                Role = AppRoles.Admin,
                Status = CustomerStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
            return new Fixture(db, id);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => true;
    }
}
