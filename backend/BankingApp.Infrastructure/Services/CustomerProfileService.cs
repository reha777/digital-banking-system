using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Profiles;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using BankingApp.Application.Auth;

namespace BankingApp.Infrastructure.Services;

public class CustomerProfileService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUser,
    IPasswordHasher passwordHasher,
    IFileValidationService? fileValidationService = null) : ICustomerProfileService
{
    public const int MaximumProfilePhotoSizeBytes = 2 * 1024 * 1024;
    private static readonly string[] AllowedPhotoTypes = ["image/jpeg", "image/png"];

    public async Task<CustomerProfileResponse> GetAsync(CancellationToken cancellationToken = default) =>
        ToResponse(await GetCustomerAsync(cancellationToken));

    public async Task<CustomerProfileResponse> UpdateAsync(
        UpdateCustomerProfileRequest request,
        CancellationToken cancellationToken = default)
    {
        var customer = await GetCustomerAsync(cancellationToken);
        customer.FirstName = request.FirstName.Trim();
        customer.LastName = request.LastName.Trim();
        customer.PhoneNumber = request.PhoneNumber.Trim();
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToResponse(customer);
    }

    public async Task ChangePasswordAsync(
        ChangeCustomerPasswordRequest request,
        CancellationToken cancellationToken = default)
    {
        var customer = await GetCustomerAsync(cancellationToken);
        if (!passwordHasher.Verify(request.CurrentPassword, customer.PasswordHash))
        {
            throw new BusinessException("Current password is incorrect.");
        }
        if (request.NewPassword.Length < PasswordPolicy.MinimumLength) throw new BusinessException("New password does not meet the password requirements.");

        customer.PasswordHash = passwordHasher.Hash(request.NewPassword);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<CustomerProfileResponse> UploadPhotoAsync(
        CustomerProfilePhotoUploadRequest request,
        CancellationToken cancellationToken = default)
    {
        var contentType = (fileValidationService ?? new FileValidationService()).ValidateProfileImage(request.ContentType, request.Content, MaximumProfilePhotoSizeBytes);

        var customer = await GetCustomerAsync(cancellationToken);
        customer.ProfilePhoto = request.Content;
        customer.ProfilePhotoContentType = contentType;
        customer.ProfilePhotoUpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToResponse(customer);
    }

    public async Task<CustomerProfilePhotoResponse> GetPhotoAsync(
        CancellationToken cancellationToken = default)
    {
        var customer = await GetCustomerAsync(cancellationToken);
        if (customer.ProfilePhoto is null || customer.ProfilePhoto.Length == 0 ||
            string.IsNullOrWhiteSpace(customer.ProfilePhotoContentType))
            throw new NotFoundException("Profile photo was not found.");
        return new(customer.ProfilePhoto, customer.ProfilePhotoContentType);
    }

    private async Task<User> GetCustomerAsync(CancellationToken cancellationToken) =>
        await dbContext.Users.SingleOrDefaultAsync(
            user => user.Id == currentUser.UserId &&
                user.Role == AppRoles.Customer &&
                !user.IsDeleted,
            cancellationToken)
        ?? throw new NotFoundException("Customer profile was not found.");

    private static CustomerProfileResponse ToResponse(User user) => new(
        user.Id,
        user.FirstName,
        user.LastName,
        user.Email,
        user.PhoneNumber,
        user.Role,
        user.ProfilePhoto is { Length: > 0 },
        user.ProfilePhotoUpdatedAtUtc);
}
