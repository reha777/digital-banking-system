using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Profiles;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public class CustomerProfileService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUser,
    IPasswordHasher passwordHasher) : ICustomerProfileService
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

        customer.PasswordHash = passwordHasher.Hash(request.NewPassword);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<CustomerProfileResponse> UploadPhotoAsync(
        CustomerProfilePhotoUploadRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.Content.Length == 0)
            throw new BusinessException("Profile photo cannot be empty.");
        if (request.Content.Length > MaximumProfilePhotoSizeBytes)
            throw new BusinessException("Profile photo cannot be larger than 2 MB.");
        if (!AllowedPhotoTypes.Contains(request.ContentType, StringComparer.OrdinalIgnoreCase) ||
            !HasValidImageSignature(request.Content, request.ContentType))
            throw new BusinessException("Only JPG and PNG profile photos are allowed.");

        var customer = await GetCustomerAsync(cancellationToken);
        customer.ProfilePhoto = request.Content;
        customer.ProfilePhotoContentType = request.ContentType.ToLowerInvariant();
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

    private static bool HasValidImageSignature(byte[] content, string contentType) =>
        contentType.Equals("image/png", StringComparison.OrdinalIgnoreCase)
            ? content.Length >= 8 && content.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 })
            : content.Length >= 3 && content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF;

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
