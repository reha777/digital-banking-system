using BankingApp.Api.Controllers;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Profiles;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using System.ComponentModel.DataAnnotations;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class CustomerProfileServiceTests
{
    [Fact]
    public void Profile_routes_require_customer_authentication()
    {
        var authorize = Assert.Single(
            typeof(ProfileController).GetCustomAttributes(typeof(AuthorizeAttribute), true)
                .Cast<AuthorizeAttribute>());

        Assert.Equal(AppRoles.Customer, authorize.Roles);
    }

    [Fact]
    public async Task Get_returns_only_the_current_customer_profile()
    {
        await using var fixture = await Fixture.CreateAsync();
        var profile = await fixture.Service.GetAsync();

        Assert.Equal(fixture.CustomerId, profile.Id);
        Assert.Equal("customer@example.com", profile.Email);
        Assert.Equal(AppRoles.Customer, profile.Role);
    }

    [Fact]
    public async Task Update_changes_allowed_fields_but_not_email_or_role()
    {
        await using var fixture = await Fixture.CreateAsync();
        var profile = await fixture.Service.UpdateAsync(new UpdateCustomerProfileRequest
        {
            FirstName = " Updated ",
            LastName = " Customer ",
            PhoneNumber = " +38761123456 "
        });

        Assert.Equal("Updated", profile.FirstName);
        Assert.Equal("customer@example.com", profile.Email);
        Assert.Equal(AppRoles.Customer, profile.Role);
    }

    [Fact]
    public async Task ChangePassword_rejects_incorrect_current_password()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ChangePasswordAsync(
            new ChangeCustomerPasswordRequest { CurrentPassword = "wrong", NewPassword = "newpass" }));
    }

    [Fact]
    public async Task ChangePassword_replaces_old_password_with_new_password()
    {
        await using var fixture = await Fixture.CreateAsync();
        await fixture.Service.ChangePasswordAsync(new ChangeCustomerPasswordRequest
        {
            CurrentPassword = "oldpass",
            NewPassword = "newpass"
        });

        var user = await fixture.Db.Users.SingleAsync(x => x.Id == fixture.CustomerId);
        Assert.False(fixture.Hasher.Verify("oldpass", user.PasswordHash));
        Assert.True(fixture.Hasher.Verify("newpass", user.PasswordHash));
    }

    [Fact]
    public void ChangePassword_contract_rejects_password_shorter_than_registration_policy()
    {
        var request = new ChangeCustomerPasswordRequest
        {
            CurrentPassword = "oldpass",
            NewPassword = "short"
        };
        var errors = new List<ValidationResult>();

        Assert.False(Validator.TryValidateObject(request, new ValidationContext(request), errors, true));
    }

    [Fact]
    public async Task UploadPhoto_accepts_valid_png_and_replaces_existing_photo()
    {
        await using var fixture = await Fixture.CreateAsync();
        var first = ValidPng(1);
        var second = ValidPng(2);

        await fixture.Service.UploadPhotoAsync(new CustomerProfilePhotoUploadRequest
        {
            ContentType = "image/png",
            Content = first
        });
        var profile = await fixture.Service.UploadPhotoAsync(new CustomerProfilePhotoUploadRequest
        {
            ContentType = "image/png",
            Content = second
        });
        var stored = await fixture.Service.GetPhotoAsync();

        Assert.True(profile.HasProfilePhoto);
        Assert.Equal(second, stored.Content);
        Assert.Equal("image/png", stored.ContentType);
    }

    [Fact]
    public async Task UploadPhoto_rejects_invalid_type_and_signature()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UploadPhotoAsync(
            new CustomerProfilePhotoUploadRequest
            {
                ContentType = "application/pdf",
                Content = [1, 2, 3]
            }));
    }

    [Fact]
    public async Task UploadPhoto_rejects_files_over_two_megabytes()
    {
        await using var fixture = await Fixture.CreateAsync();
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.UploadPhotoAsync(
            new CustomerProfilePhotoUploadRequest
            {
                ContentType = "image/png",
                Content = new byte[CustomerProfileService.MaximumProfilePhotoSizeBytes + 1]
            }));
    }

    [Fact]
    public async Task UploadPhoto_only_updates_the_authenticated_customer()
    {
        await using var fixture = await Fixture.CreateAsync();
        var otherId = Guid.NewGuid();
        fixture.Db.Users.Add(new User
        {
            Id = otherId,
            FirstName = "Other",
            LastName = "Customer",
            Email = "other@example.com",
            PhoneNumber = "+38762000000",
            PasswordHash = fixture.Hasher.Hash("oldpass"),
            Role = AppRoles.Customer,
            Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        });
        await fixture.Db.SaveChangesAsync();

        await fixture.Service.UploadPhotoAsync(new CustomerProfilePhotoUploadRequest
        {
            ContentType = "image/png",
            Content = ValidPng(1)
        });

        Assert.Null((await fixture.Db.Users.SingleAsync(x => x.Id == otherId)).ProfilePhoto);
        Assert.NotNull((await fixture.Db.Users.SingleAsync(x => x.Id == fixture.CustomerId)).ProfilePhoto);
    }

    private static byte[] ValidPng(byte marker) => [137, 80, 78, 71, 13, 10, 26, 10, marker];

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Guid customerId, Pbkdf2PasswordHasher hasher)
        {
            Db = db;
            CustomerId = customerId;
            Hasher = hasher;
            Service = new CustomerProfileService(db, new CurrentUser(customerId), hasher);
        }

        public BankingAppDbContext Db { get; }
        public Guid CustomerId { get; }
        public Pbkdf2PasswordHasher Hasher { get; }
        public CustomerProfileService Service { get; }

        public static async Task<Fixture> CreateAsync()
        {
            var options = new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;
            var db = new BankingAppDbContext(options);
            var id = Guid.NewGuid();
            var hasher = new Pbkdf2PasswordHasher();
            db.Users.Add(new User
            {
                Id = id,
                FirstName = "Test",
                LastName = "Customer",
                Email = "customer@example.com",
                PhoneNumber = "+38761000000",
                PasswordHash = hasher.Hash("oldpass"),
                Role = AppRoles.Customer,
                Status = CustomerStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
            return new Fixture(db, id, hasher);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => false;
    }
}
