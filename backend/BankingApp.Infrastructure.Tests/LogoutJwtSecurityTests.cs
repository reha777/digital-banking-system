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
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class LogoutJwtSecurityTests
{
    [Fact]
    public async Task Valid_signed_access_token_and_refresh_token_are_revoked()
    {
        await using var fixture = await Fixture.Create();
        var accessToken = fixture.CreateToken();

        await fixture.Service.LogoutAsync(new LogoutRequest
        {
            AccessToken = accessToken,
            RefreshToken = fixture.RefreshTokenValue
        });

        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);
        Assert.Single(fixture.Db.AccessTokenRevocations);
    }

    [Fact]
    public async Task Forged_access_token_is_rejected_without_revoking_refresh_token()
    {
        await using var fixture = await Fixture.Create();
        var valid = fixture.CreateToken();
        var forged = valid[..^1] + (valid[^1] == 'A' ? 'B' : 'A');

        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.LogoutAsync(new LogoutRequest
            {
                AccessToken = forged,
                RefreshToken = fixture.RefreshTokenValue
            }));

        Assert.Null(fixture.RefreshToken.RevokedAtUtc);
        Assert.Empty(fixture.Db.AccessTokenRevocations);
    }

    [Theory]
    [InlineData("wrong-issuer", "banking-clients")]
    [InlineData("banking-api", "wrong-audience")]
    public async Task Invalid_issuer_or_audience_is_rejected(
        string issuer,
        string audience)
    {
        await using var fixture = await Fixture.Create();

        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.LogoutAsync(new LogoutRequest
            {
                AccessToken = fixture.CreateToken(issuer, audience),
                RefreshToken = fixture.RefreshTokenValue
            }));
    }

    [Fact]
    public async Task Expired_but_validly_signed_access_token_is_accepted_for_logout()
    {
        await using var fixture = await Fixture.Create();

        await fixture.Service.LogoutAsync(new LogoutRequest
        {
            AccessToken = fixture.CreateToken(
                expires: DateTime.UtcNow.AddMinutes(-1)),
            RefreshToken = fixture.RefreshTokenValue
        });

        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);
        Assert.Single(fixture.Db.AccessTokenRevocations);
    }

    [Fact]
    public async Task Refresh_token_can_be_revoked_without_access_token()
    {
        await using var fixture = await Fixture.Create();

        await fixture.Service.LogoutAsync(new LogoutRequest
        {
            RefreshToken = fixture.RefreshTokenValue
        });

        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);
        Assert.Empty(fixture.Db.AccessTokenRevocations);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private const string Issuer = "banking-api";
        private const string Audience = "banking-clients";
        private const string Key = "logout-validation-test-key-with-at-least-32-bytes";

        private Fixture(
            BankingAppDbContext db,
            User user,
            RefreshToken refreshToken,
            string refreshTokenValue,
            AuthService service)
        {
            Db = db;
            User = user;
            RefreshToken = refreshToken;
            RefreshTokenValue = refreshTokenValue;
            Service = service;
        }

        public BankingAppDbContext Db { get; }
        public User User { get; }
        public RefreshToken RefreshToken { get; }
        public string RefreshTokenValue { get; }
        public AuthService Service { get; }

        public static async Task<Fixture> Create()
        {
            var db = new BankingAppDbContext(
                new DbContextOptionsBuilder<BankingAppDbContext>()
                    .UseInMemoryDatabase(Guid.NewGuid().ToString())
                    .Options);
            var user = new User
            {
                Id = Guid.NewGuid(),
                FirstName = "Logout",
                LastName = "User",
                Email = "logout@example.com",
                PhoneNumber = "+38761000000",
                PasswordHash = "unused",
                Role = AppRoles.Customer,
                Status = CustomerStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            const string refreshTokenValue = "valid-refresh-token";
            var refreshToken = new RefreshToken
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                User = user,
                TokenHash = Convert.ToHexString(SHA256.HashData(
                    Encoding.UTF8.GetBytes(refreshTokenValue))),
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddDays(1)
            };
            db.AddRange(user, refreshToken);
            await db.SaveChangesAsync();
            var jwtOptions = Options.Create(new JwtOptions
            {
                Issuer = Issuer,
                Audience = Audience,
                Key = Key,
                ExpirationMinutes = 60,
                RefreshTokenExpirationDays = 14
            });
            var service = new AuthService(
                db,
                new Pbkdf2PasswordHasher(),
                new JwtTokenGenerator(jwtOptions),
                jwtOptions,
                Options.Create(new DemoAuthOptions()),
                new NoOpEmailService(),
                new UserSessionRevocationService(db),
                NullLogger<AuthService>.Instance);
            return new Fixture(db, user, refreshToken, refreshTokenValue, service);
        }

        public string CreateToken(
            string issuer = Issuer,
            string audience = Audience,
            DateTime? expires = null)
        {
            var credentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Key)),
                SecurityAlgorithms.HmacSha256);
            var token = new JwtSecurityToken(
                issuer,
                audience,
                [
                    new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                    new Claim(JwtRegisteredClaimNames.Sub, User.Id.ToString()),
                    new Claim(ClaimTypes.NameIdentifier, User.Id.ToString())
                ],
                expires: expires ?? DateTime.UtcNow.AddMinutes(5),
                signingCredentials: credentials);
            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class NoOpEmailService : IEmailService
    {
        public Task SendPasswordResetAsync(
            string recipientEmail,
            string token,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
