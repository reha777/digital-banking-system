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
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class PasswordResetTests
{
    [Fact]
    public async Task Forgot_is_generic_for_known_and_unknown_email_and_stores_only_hash()
    {
        await using var fixture = await Fixture.Create();
        var known = await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email });
        var unknown = await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = "unknown@example.com" });
        Assert.Equal(known.Message, unknown.Message); var stored = Assert.Single(fixture.Db.PasswordResetTokens);
        Assert.NotEqual(fixture.Email.Token, stored.TokenHash); Assert.Equal(64, stored.TokenHash.Length);
    }

    [Fact]
    public async Task Second_request_revokes_previous_token()
    {
        await using var fixture = await Fixture.Create();
        await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email }); var first = fixture.Email.Token;
        await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email });
        Assert.NotNull((await fixture.Db.PasswordResetTokens.SingleAsync(x => x.TokenHash != Hash(fixture.Email.Token))).RevokedAtUtc);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ResetPasswordAsync(Request(first)));
    }

    [Fact]
    public async Task Valid_reset_changes_password_is_single_use_and_revokes_refresh_sessions()
    {
        await using var fixture = await Fixture.Create();
        await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email }); var token = fixture.Email.Token;
        await fixture.Service.ResetPasswordAsync(Request(token));
        Assert.True(fixture.Hasher.Verify("new-password", fixture.User.PasswordHash)); Assert.NotNull(fixture.Refresh.RevokedAtUtc);
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ResetPasswordAsync(Request(token)));
        await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.LoginAsync(new LoginRequest { Email = fixture.User.Email, Password = "old-password" }));
        Assert.NotNull(await fixture.Service.LoginAsync(new LoginRequest { Email = fixture.User.Email, Password = "new-password" }));
    }

    [Fact]
    public async Task Expired_and_invalid_tokens_return_same_safe_error()
    {
        await using var fixture = await Fixture.Create();
        await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email }); var token = fixture.Email.Token;
        (await fixture.Db.PasswordResetTokens.SingleAsync()).ExpiresAtUtc = DateTime.UtcNow.AddSeconds(-1); await fixture.Db.SaveChangesAsync();
        var expired = await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ResetPasswordAsync(Request(token)));
        var invalid = await Assert.ThrowsAsync<BusinessException>(() => fixture.Service.ResetPasswordAsync(Request("invalid")));
        Assert.Equal(expired.Message, invalid.Message);
    }

    [Fact]
    public async Task Disabled_or_deleted_customer_gets_generic_response_without_a_token()
    {
        await using var fixture = await Fixture.Create();
        fixture.User.Status = CustomerStatus.Blocked; await fixture.Db.SaveChangesAsync();
        var blocked = await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email });
        fixture.User.Status = CustomerStatus.Active; fixture.User.IsDeleted = true; await fixture.Db.SaveChangesAsync();
        var deleted = await fixture.Service.ForgotPasswordAsync(new ForgotPasswordRequest { Email = fixture.User.Email });
        Assert.Equal(blocked.Message, deleted.Message); Assert.Empty(fixture.Db.PasswordResetTokens);
    }

    private static ResetPasswordRequest Request(string token) => new() { Token = token, NewPassword = "new-password", ConfirmPassword = "new-password" };
    private static string Hash(string token) => Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token)));

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User user, RefreshToken refresh, Pbkdf2PasswordHasher hasher, CapturingEmail email, AuthService service) { Db = db; User = user; Refresh = refresh; Hasher = hasher; Email = email; Service = service; }
        public BankingAppDbContext Db { get; } public User User { get; } public RefreshToken Refresh { get; } public Pbkdf2PasswordHasher Hasher { get; } public CapturingEmail Email { get; } public AuthService Service { get; }
        public static async Task<Fixture> Create()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options); var hasher = new Pbkdf2PasswordHasher();
            var user = new User { Id = Guid.NewGuid(), FirstName = "Reset", LastName = "User", Email = "reset@example.com", PhoneNumber = "+38761000000", PasswordHash = hasher.Hash("old-password"), Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            var refresh = new RefreshToken { Id = Guid.NewGuid(), UserId = user.Id, User = user, TokenHash = Guid.NewGuid().ToString(), CreatedAtUtc = DateTime.UtcNow, ExpiresAtUtc = DateTime.UtcNow.AddDays(1) }; db.AddRange(user, refresh); await db.SaveChangesAsync();
            var email = new CapturingEmail(); var service = new AuthService(db, hasher, new FakeJwt(), Options.Create(new JwtOptions { ExpirationMinutes = 60, RefreshTokenExpirationDays = 14 }), Options.Create(new DemoAuthOptions()), email, new UserSessionRevocationService(db), NullLogger<AuthService>.Instance); return new Fixture(db, user, refresh, hasher, email, service);
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CapturingEmail : IEmailService { public string Token { get; private set; } = string.Empty; public Task SendPasswordResetAsync(string recipientEmail, string token, DateTime expiresAtUtc, CancellationToken cancellationToken = default) { Token = token; return Task.CompletedTask; } }
    private sealed class FakeJwt : IJwtTokenGenerator { public string GenerateToken(User user) => "jwt"; }
}
