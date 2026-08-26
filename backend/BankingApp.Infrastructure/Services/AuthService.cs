using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.ComponentModel.DataAnnotations;
using BankingApp.Application.Auth;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;

namespace BankingApp.Infrastructure.Services
{
    public class AuthService(
        BankingAppDbContext dbContext,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator,
        IOptions<JwtOptions> jwtOptions,
        IOptions<DemoAuthOptions> demoAuthOptions,
        IEmailService emailService,
        IUserSessionRevocationService sessionRevocationService,
        ILogger<AuthService> logger) : IAuthService
    {
        private readonly JwtOptions _jwtOptions = jwtOptions.Value;
        private readonly DemoAuthOptions _demoAuthOptions = demoAuthOptions.Value;

        public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
        {
            var email = request.Email.Trim().ToLowerInvariant();
            var user = await dbContext.Users
                .FirstOrDefaultAsync(existingUser => existingUser.Email == email, cancellationToken);

            if (user is null || !passwordHasher.Verify(request.Password, user.PasswordHash))
            {
                throw new BusinessException("Email ili lozinka nisu ispravni.");
            }

            EnsureUserCanAuthenticate(user);

            return await CreateAuthResponseAsync(user, cancellationToken);
        }

        public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
        {
            var email = request.Email.Trim().ToLowerInvariant();
            var emailExists = await dbContext.Users
                .AnyAsync(user => user.Email == email, cancellationToken);

            if (emailExists)
            {
                throw new BusinessException("Korisnik sa ovom email adresom vec postoji.");
            }

            var user = new User
            {
                Id = Guid.NewGuid(),
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                Email = email,
                PhoneNumber = request.PhoneNumber.Trim(),
                PasswordHash = passwordHasher.Hash(request.Password),
                Role = AppRoles.Customer,
                Status = CustomerStatus.Active,
                IsDeleted = false,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.Users.Add(user);

            return await CreateAuthResponseAsync(user, cancellationToken);
        }

        public async Task<AuthResponse> RefreshAsync(
            RefreshTokenRequest request,
            CancellationToken cancellationToken = default)
        {
            var tokenHash = HashRefreshToken(request.RefreshToken);
            var refreshToken = await dbContext.RefreshTokens
                .Include(token => token.User)
                .FirstOrDefaultAsync(token => token.TokenHash == tokenHash, cancellationToken);

            if (refreshToken is null || !refreshToken.IsActive)
            {
                throw new BusinessException("Refresh token nije validan ili je istekao.");
            }

            EnsureUserCanAuthenticate(refreshToken.User);

            refreshToken.RevokedAtUtc = DateTime.UtcNow;
            return await CreateAuthResponseAsync(refreshToken.User, cancellationToken);
        }

        public async Task LogoutAsync(LogoutRequest request, CancellationToken cancellationToken = default)
        {
            var hasChanges = await RevokeAccessTokenAsync(request.AccessToken, cancellationToken);

            var tokenHash = HashRefreshToken(request.RefreshToken);
            var refreshToken = await dbContext.RefreshTokens
                .FirstOrDefaultAsync(token => token.TokenHash == tokenHash, cancellationToken);

            if (refreshToken is not null && refreshToken.RevokedAtUtc is null)
            {
                refreshToken.RevokedAtUtc = DateTime.UtcNow;
                hasChanges = true;
            }

            if (hasChanges)
            {
                await dbContext.SaveChangesAsync(cancellationToken);
            }
        }

        public async Task<ForgotPasswordResponse> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken cancellationToken = default)
        {
            var response = new ForgotPasswordResponse();
            var email = request.Email.Trim().ToLowerInvariant();
            var user = await dbContext.Users.FirstOrDefaultAsync(value => value.Email == email, cancellationToken);
            if (user is null || user.IsDeleted || (user.Role == AppRoles.Customer && user.Status != CustomerStatus.Active)) return response;

            return await IssuePasswordResetAsync(user, user.Email, response, cancellationToken);
        }

        public async Task<ForgotPasswordResponse> DemoForgotPasswordAsync(
            DemoForgotPasswordRequest request,
            CancellationToken cancellationToken = default)
        {
            var response = new ForgotPasswordResponse();
            if (!_demoAuthOptions.Enabled) return response;
            if (!new EmailAddressAttribute().IsValid(request.Email))
                throw new BusinessException("Demo delivery email is invalid.");

            var selection = request.DemoAccount.Trim().ToLowerInvariant() switch
            {
                "customer-primary" => (_demoAuthOptions.CustomerPrimaryAccountEmail, AppRoles.Customer),
                "customer-secondary" => (_demoAuthOptions.CustomerSecondaryAccountEmail, AppRoles.Customer),
                "admin" => (_demoAuthOptions.AdminAccountEmail, AppRoles.Admin),
                _ => throw new BusinessException("Demo account is invalid.")
            };
            var accountEmail = selection.Item1.Trim().ToLowerInvariant();
            var expectedRole = selection.Item2;
            var user = await dbContext.Users.FirstOrDefaultAsync(
                value => value.Email == accountEmail && value.Role == expectedRole,
                cancellationToken);
            if (user is null)
            {
                logger.LogWarning(
                    "Configured {DemoAccount} demo account was not found.",
                    request.DemoAccount);
                return response;
            }
            if (user.IsDeleted ||
                (user.Role == AppRoles.Customer && user.Status != CustomerStatus.Active))
                return response;

            return await IssuePasswordResetAsync(
                user,
                request.Email.Trim().ToLowerInvariant(),
                response,
                cancellationToken);
        }

        private async Task<ForgotPasswordResponse> IssuePasswordResetAsync(
            User user,
            string deliveryEmail,
            ForgotPasswordResponse response,
            CancellationToken cancellationToken)
        {
            var now = DateTime.UtcNow;
            var activeTokens = await dbContext.PasswordResetTokens.Where(value => value.UserId == user.Id && value.UsedAtUtc == null && value.RevokedAtUtc == null && value.ExpiresAtUtc > now).ToListAsync(cancellationToken);
            foreach (var oldToken in activeTokens) oldToken.RevokedAtUtc = now;
            var plaintext = CreatePasswordResetToken(); var expires = now.AddMinutes(30);
            dbContext.PasswordResetTokens.Add(new PasswordResetToken { Id = Guid.NewGuid(), UserId = user.Id, TokenHash = HashSecurityToken(plaintext), CreatedAtUtc = now, ExpiresAtUtc = expires });
            await dbContext.SaveChangesAsync(cancellationToken);
            try { await emailService.SendPasswordResetAsync(deliveryEmail, plaintext, expires, cancellationToken); }
            catch (Exception exception)
            {
                logger.LogError(exception, "Password reset email delivery failed.");
                // The public response intentionally remains generic.
            }
            return response;
        }

        public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default)
        {
            const string safeError = "Reset code is invalid or expired.";
            if (request.NewPassword != request.ConfirmPassword || request.NewPassword.Length < PasswordPolicy.MinimumLength) throw new BusinessException("New password does not meet the password requirements.");
            var now = DateTime.UtcNow; var hash = HashSecurityToken(request.Token.Trim());
            var resetToken = await dbContext.PasswordResetTokens.Include(value => value.User).SingleOrDefaultAsync(value => value.TokenHash == hash, cancellationToken);
            if (resetToken is null || resetToken.UsedAtUtc != null || resetToken.RevokedAtUtc != null || resetToken.ExpiresAtUtc <= now || resetToken.User.IsDeleted || (resetToken.User.Role == AppRoles.Customer && resetToken.User.Status != CustomerStatus.Active)) throw new BusinessException(safeError);
            resetToken.User.PasswordHash = passwordHasher.Hash(request.NewPassword); resetToken.UsedAtUtc = now;
            await sessionRevocationService.RevokeAllRefreshTokensAsync(resetToken.UserId, cancellationToken);
            try { await dbContext.SaveChangesAsync(cancellationToken); }
            catch (DbUpdateConcurrencyException) { throw new BusinessException(safeError); }
        }

        private async Task<bool> RevokeAccessTokenAsync(string? accessToken, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(accessToken))
            {
                return false;
            }

            JwtSecurityToken jwtToken;
            try
            {
                jwtToken = new JwtSecurityTokenHandler().ReadJwtToken(accessToken);
            }
            catch (ArgumentException)
            {
                return false;
            }

            var tokenId = jwtToken.Claims.FirstOrDefault(claim => claim.Type == JwtRegisteredClaimNames.Jti)?.Value;
            if (string.IsNullOrWhiteSpace(tokenId))
            {
                return false;
            }

            var alreadyRevoked = await dbContext.AccessTokenRevocations
                .AnyAsync(revocation => revocation.TokenId == tokenId, cancellationToken);

            if (alreadyRevoked)
            {
                return false;
            }

            var userIdValue = jwtToken.Claims.FirstOrDefault(claim => claim.Type == ClaimTypes.NameIdentifier)?.Value
                ?? jwtToken.Claims.FirstOrDefault(claim => claim.Type == JwtRegisteredClaimNames.Sub)?.Value;

            dbContext.AccessTokenRevocations.Add(new AccessTokenRevocation
            {
                Id = Guid.NewGuid(),
                TokenId = tokenId,
                UserId = Guid.TryParse(userIdValue, out var userId) ? userId : null,
                ExpiresAtUtc = jwtToken.ValidTo,
                RevokedAtUtc = DateTime.UtcNow
            });

            return true;
        }

        private async Task<AuthResponse> CreateAuthResponseAsync(User user, CancellationToken cancellationToken)
        {
            EnsureUserCanAuthenticate(user);

            var refreshTokenValue = CreateRefreshTokenValue();
            var refreshTokenExpiresAtUtc = DateTime.UtcNow.AddDays(_jwtOptions.RefreshTokenExpirationDays);

            dbContext.RefreshTokens.Add(new RefreshToken
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                TokenHash = HashRefreshToken(refreshTokenValue),
                ExpiresAtUtc = refreshTokenExpiresAtUtc,
                CreatedAtUtc = DateTime.UtcNow
            });

            await dbContext.SaveChangesAsync(cancellationToken);

            return CreateAuthResponse(user, refreshTokenValue, refreshTokenExpiresAtUtc);
        }

        private AuthResponse CreateAuthResponse(
            User user,
            string refreshToken,
            DateTime refreshTokenExpiresAtUtc)
        {
            return new AuthResponse
            {
                Token = jwtTokenGenerator.GenerateToken(user),
                TokenExpiresAtUtc = DateTime.UtcNow.AddMinutes(_jwtOptions.ExpirationMinutes),
                RefreshToken = refreshToken,
                RefreshTokenExpiresAtUtc = refreshTokenExpiresAtUtc,
                User = new UserResponse
                {
                    Id = user.Id,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    Email = user.Email,
                    PhoneNumber = user.PhoneNumber,
                    Role = user.Role,
                    HasProfilePhoto = user.ProfilePhoto is { Length: > 0 },
                    ProfilePhotoUpdatedAtUtc = user.ProfilePhotoUpdatedAtUtc
                }
            };
        }

        private static string CreateRefreshTokenValue()
        {
            return Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        }

        private static string HashRefreshToken(string refreshToken)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken));
            return Convert.ToHexString(bytes);
        }

        private static string CreatePasswordResetToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        private static string HashSecurityToken(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

        private static void EnsureUserCanAuthenticate(User user)
        {
            if (user.IsDeleted)
            {
                throw new AccountDisabledException();
            }

            if (user.Role == AppRoles.Customer && user.Status != CustomerStatus.Active)
            {
                throw new AccountDisabledException();
            }
        }
    }
}
