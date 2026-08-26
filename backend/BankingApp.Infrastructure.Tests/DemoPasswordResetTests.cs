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
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class DemoPasswordResetTests
{
    [Fact]
    public async Task Disabled_demo_keeps_standard_account_email_semantics()
    {
        await using var fixture = await Fixture.Create(enabled: false);

        await fixture.Service.ForgotPasswordAsync(
            new ForgotPasswordRequest { Email = fixture.Customer.Email });

        Assert.Equal(fixture.Customer.Email, fixture.Email.Recipient);
        Assert.Equal(fixture.Customer.Id, Assert.Single(fixture.Db.PasswordResetTokens).UserId);
    }

    [Theory]
    [InlineData("Customer")]
    [InlineData("Admin")]
    public async Task Demo_context_selects_configured_account_and_arbitrary_delivery_email(
        string clientType)
    {
        await using var fixture = await Fixture.Create();
        const string deliveryEmail = "professor@example.com";

        await fixture.Service.DemoForgotPasswordAsync(new DemoForgotPasswordRequest
        {
            Email = deliveryEmail,
            ClientType = clientType,
        });

        var expected = clientType == "Customer" ? fixture.Customer : fixture.Admin;
        var stored = Assert.Single(fixture.Db.PasswordResetTokens);
        Assert.Equal(expected.Id, stored.UserId);
        Assert.Equal(deliveryEmail, fixture.Email.Recipient);
        Assert.NotEqual(fixture.Email.Token, stored.TokenHash);
        Assert.Equal(64, stored.TokenHash.Length);
        Assert.DoesNotContain(
            typeof(DemoForgotPasswordRequest).GetProperties(),
            property => property.Name.Contains("Id", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Invalid_client_type_is_rejected()
    {
        await using var fixture = await Fixture.Create();
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.DemoForgotPasswordAsync(new DemoForgotPasswordRequest
            {
                Email = "professor@example.com",
                ClientType = "Manager",
            }));
    }

    [Fact]
    public async Task Invalid_delivery_email_is_rejected()
    {
        await using var fixture = await Fixture.Create();
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.DemoForgotPasswordAsync(new DemoForgotPasswordRequest
            {
                Email = "not-an-email",
                ClientType = "Customer",
            }));
    }

    [Fact]
    public async Task Missing_configured_seed_account_returns_generic_without_token()
    {
        await using var fixture = await Fixture.Create(
            customerAccountEmail: "missing@bankingapp.local");

        var response = await fixture.Service.DemoForgotPasswordAsync(
            new DemoForgotPasswordRequest
            {
                Email = "professor@example.com",
                ClientType = "Customer",
            });

        Assert.Equal(
            new ForgotPasswordResponse().Message,
            response.Message);
        Assert.Empty(fixture.Db.PasswordResetTokens);
        Assert.Null(fixture.Email.Recipient);
    }

    [Theory]
    [InlineData(true, CustomerStatus.Active)]
    [InlineData(false, CustomerStatus.Blocked)]
    public async Task Deleted_or_blocked_demo_customer_does_not_receive_token(
        bool deleted,
        CustomerStatus status)
    {
        await using var fixture = await Fixture.Create();
        fixture.Customer.IsDeleted = deleted;
        fixture.Customer.Status = status;
        await fixture.Db.SaveChangesAsync();

        await fixture.Service.DemoForgotPasswordAsync(new DemoForgotPasswordRequest
        {
            Email = "professor@example.com",
            ClientType = "Customer",
        });

        Assert.Empty(fixture.Db.PasswordResetTokens);
        Assert.Null(fixture.Email.Recipient);
    }

    [Fact]
    public async Task Demo_token_resets_seed_password_once_and_revokes_refresh_session()
    {
        await using var fixture = await Fixture.Create();
        await fixture.Service.DemoForgotPasswordAsync(new DemoForgotPasswordRequest
        {
            Email = "professor@example.com",
            ClientType = "Customer",
        });

        var request = new ResetPasswordRequest
        {
            Token = fixture.Email.Token,
            NewPassword = "new-demo-password",
            ConfirmPassword = "new-demo-password",
        };
        await fixture.Service.ResetPasswordAsync(request);

        Assert.True(fixture.Hasher.Verify(
            "new-demo-password",
            fixture.Customer.PasswordHash));
        Assert.NotNull(fixture.RefreshToken.RevokedAtUtc);
        await Assert.ThrowsAsync<BusinessException>(() =>
            fixture.Service.ResetPasswordAsync(request));
    }

    [Fact]
    public void Production_rejects_enabled_demo_auth()
    {
        var result = new DemoAuthOptionsValidator(isProduction: true).Validate(
            null,
            new DemoAuthOptions
            {
                Enabled = true,
                CustomerAccountEmail = "mobile@bankingapp.local",
                AdminAccountEmail = "admin@bankingapp.local",
            });

        Assert.True(result.Failed);
        Assert.Contains("Production", result.FailureMessage);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(
            BankingAppDbContext db,
            User customer,
            User admin,
            RefreshToken refreshToken,
            Pbkdf2PasswordHasher hasher,
            CapturingEmail email,
            AuthService service)
        {
            Db = db;
            Customer = customer;
            Admin = admin;
            RefreshToken = refreshToken;
            Hasher = hasher;
            Email = email;
            Service = service;
        }

        public BankingAppDbContext Db { get; }
        public User Customer { get; }
        public User Admin { get; }
        public RefreshToken RefreshToken { get; }
        public Pbkdf2PasswordHasher Hasher { get; }
        public CapturingEmail Email { get; }
        public AuthService Service { get; }

        public static async Task<Fixture> Create(
            bool enabled = true,
            string customerAccountEmail = "mobile@bankingapp.local")
        {
            var db = new BankingAppDbContext(
                new DbContextOptionsBuilder<BankingAppDbContext>()
                    .UseInMemoryDatabase(Guid.NewGuid().ToString())
                    .Options);
            var hasher = new Pbkdf2PasswordHasher();
            var customer = new User
            {
                Id = Guid.NewGuid(),
                FirstName = "Demo",
                LastName = "Customer",
                Email = "mobile@bankingapp.local",
                PhoneNumber = "+38761000000",
                PasswordHash = hasher.Hash("old-password"),
                Role = AppRoles.Customer,
                Status = CustomerStatus.Active,
                CreatedAtUtc = DateTime.UtcNow,
            };
            var admin = new User
            {
                Id = Guid.NewGuid(),
                FirstName = "Desktop",
                LastName = "Admin",
                Email = "admin@bankingapp.local",
                PhoneNumber = "+38761000001",
                PasswordHash = hasher.Hash("old-password"),
                Role = AppRoles.Admin,
                Status = CustomerStatus.Active,
                CreatedAtUtc = DateTime.UtcNow,
            };
            var refresh = new RefreshToken
            {
                Id = Guid.NewGuid(),
                UserId = customer.Id,
                User = customer,
                TokenHash = Guid.NewGuid().ToString(),
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddDays(1),
            };
            db.AddRange(customer, admin, refresh);
            await db.SaveChangesAsync();

            var email = new CapturingEmail();
            var demoOptions = Options.Create(new DemoAuthOptions
            {
                Enabled = enabled,
                CustomerAccountEmail = customerAccountEmail,
                AdminAccountEmail = admin.Email,
            });
            var service = new AuthService(
                db,
                hasher,
                new FakeJwt(),
                Options.Create(new JwtOptions
                {
                    ExpirationMinutes = 60,
                    RefreshTokenExpirationDays = 14,
                }),
                demoOptions,
                email,
                new UserSessionRevocationService(db),
                NullLogger<AuthService>.Instance);
            return new Fixture(
                db,
                customer,
                admin,
                refresh,
                hasher,
                email,
                service);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CapturingEmail : IEmailService
    {
        public string? Recipient { get; private set; }
        public string Token { get; private set; } = string.Empty;

        public Task SendPasswordResetAsync(
            string recipientEmail,
            string token,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            Recipient = recipientEmail;
            Token = token;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeJwt : IJwtTokenGenerator
    {
        public string GenerateToken(User user) => "jwt";
    }
}
