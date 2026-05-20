using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
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

namespace BankingApp.Infrastructure.Services
{
    public class AuthService(
        BankingAppDbContext dbContext,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator,
        IOptions<JwtOptions> jwtOptions) : IAuthService
    {
        private readonly JwtOptions _jwtOptions = jwtOptions.Value;

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
                    Role = user.Role
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

        private static void EnsureUserCanAuthenticate(User user)
        {
            if (user.IsDeleted)
            {
                throw new BusinessException("Korisnicki nalog vise nije aktivan.");
            }

            if (user.Role == AppRoles.Customer && user.Status != CustomerStatus.Active)
            {
                throw new BusinessException("Korisnicki nalog nije aktivan.");
            }
        }
    }
}
