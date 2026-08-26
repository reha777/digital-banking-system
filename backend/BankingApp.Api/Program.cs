using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using BankingApp.Api.Configuration;
using BankingApp.Api.Middleware;
using BankingApp.Api.Services;
using BankingApp.Application.Auth;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Messaging;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using System.Threading.RateLimiting;

EnvFileLoader.Load();

var builder = WebApplication.CreateBuilder(args);
const string CorsPolicyName = "ConfiguredOrigins";

builder.Services.AddOpenApi();
builder.Services.AddControllers();
builder.Services.AddHealthChecks();
builder.Services.AddRateLimiter(options => options.AddPolicy("forgot-password", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })));
builder.Services.AddDbContext<BankingAppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlServerOptions => sqlServerOptions.EnableRetryOnFailure()));

var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy =>
    {
        policy
            .SetIsOriginAllowed(origin => IsAllowedOrigin(origin, allowedOrigins, builder.Environment.IsDevelopment()))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<RabbitMqOptions>(builder.Configuration.GetSection(RabbitMqOptions.SectionName));
builder.Services.AddOptions<DemoAuthOptions>()
    .Bind(builder.Configuration.GetSection(DemoAuthOptions.SectionName))
    .ValidateOnStart();
builder.Services.AddSingleton<IValidateOptions<DemoAuthOptions>>(
    new DemoAuthOptionsValidator(builder.Environment.IsProduction()));

var jwtOptions = builder.Configuration
    .GetSection(JwtOptions.SectionName)
    .Get<JwtOptions>() ?? new JwtOptions();

if (string.IsNullOrWhiteSpace(jwtOptions.Key))
{
    throw new InvalidOperationException("JWT key is not configured.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Key))
        };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var tokenId = context.Principal?.FindFirstValue(JwtRegisteredClaimNames.Jti);
                if (string.IsNullOrWhiteSpace(tokenId))
                {
                    context.Fail("Token id is missing.");
                    return;
                }

                var dbContext = context.HttpContext.RequestServices.GetRequiredService<BankingAppDbContext>();
                var isRevoked = await dbContext.AccessTokenRevocations
                    .AnyAsync(revocation =>
                        revocation.TokenId == tokenId &&
                        revocation.ExpiresAtUtc > DateTime.UtcNow);

                if (isRevoked)
                {
                    context.Fail("Token has been revoked.");
                    return;
                }

                var role = context.Principal?.FindFirstValue(ClaimTypes.Role);
                if (role == AppRoles.Customer)
                {
                    var userIdValue = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier)
                        ?? context.Principal?.FindFirstValue(JwtRegisteredClaimNames.Sub);
                    if (!Guid.TryParse(userIdValue, out var userId))
                    {
                        context.Fail("Customer id is invalid.");
                        return;
                    }

                    var validator = context.HttpContext.RequestServices
                        .GetRequiredService<ICustomerAccessValidator>();
                    if (!await validator.IsActiveCustomerAsync(
                            userId,
                            context.HttpContext.RequestAborted))
                    {
                        context.HttpContext.Items["AuthErrorCode"] = "account_disabled";
                        context.Fail("Customer account is disabled.");
                    }
                }
            },
            OnChallenge = async context =>
            {
                if (context.HttpContext.Items["AuthErrorCode"] as string != "account_disabled")
                {
                    return;
                }

                context.HandleResponse();
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsJsonAsync(new
                {
                    code = "account_disabled",
                    message = "Your account is no longer active. Please contact support."
                });
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<IFileValidationService, FileValidationService>();
builder.Services.AddScoped<INotificationWriter, NotificationWriter>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddConfiguredEmailDelivery(
    builder.Configuration,
    builder.Environment.ContentRootPath,
    builder.Environment.IsProduction());
builder.Services.AddScoped<ICustomerAccessValidator, CustomerAccessValidator>();
builder.Services.AddScoped<IUserSessionRevocationService, UserSessionRevocationService>();
builder.Services.AddScoped<IAuditLogService, AuditLogService>();
builder.Services.AddScoped<IAuditArchiveRequestService, AuditArchiveRequestService>();
builder.Services.AddSingleton<IAuditArchivePublisher, RabbitMqAuditArchivePublisher>();
builder.Services.AddScoped<IAccountService, AccountService>();
builder.Services.AddScoped<ITransactionService, TransactionService>();
builder.Services.AddSingleton<ICurrencyConversionService, DemoCurrencyConversionService>();
builder.Services.AddScoped<IAdminCustomerService, AdminCustomerService>();
builder.Services.AddScoped<IAdminDashboardService, AdminDashboardService>();
builder.Services.AddScoped<ICardService, CardService>();
builder.Services.AddScoped<IAdminSettingsService, AdminSettingsService>();
builder.Services.AddScoped<ICustomerProfileService, CustomerProfileService>();
builder.Services.AddScoped<ILoanService, LoanService>();
builder.Services.AddScoped<ILoanRecommendationService, LoanRecommendationService>();
builder.Services.AddScoped<IReferenceDataService, ReferenceDataService>();
builder.Services.AddScoped<IAdminReportService, AdminReportService>();
builder.Services.AddSingleton<IReportGenerationPublisher, RabbitMqReportGenerationPublisher>();
builder.Services.AddScoped<IAdminLoanService, AdminLoanService>();
builder.Services.AddSingleton<ILoanCalculationService, LoanCalculationService>();
builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
builder.Services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

var app = builder.Build();

if (builder.Configuration.GetValue<bool>("Database:ApplyMigrations"))
{
    await ApplyMigrationsAsync(app);
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseHttpsRedirection();
app.UseCors(CorsPolicyName);
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapHealthChecks("/health");
app.MapControllers();

var demoAuth = builder.Configuration
    .GetSection(DemoAuthOptions.SectionName)
    .Get<DemoAuthOptions>() ?? new DemoAuthOptions();
if (demoAuth.Enabled)
{
    if (app.Environment.IsProduction())
        throw new InvalidOperationException("DemoAuth cannot be enabled in Production.");

    app.MapPost(
            "/api/auth/demo/forgot-password",
            async (
                DemoForgotPasswordRequest request,
                IAuthService authService,
                CancellationToken cancellationToken) =>
                Results.Ok(await authService.DemoForgotPasswordAsync(request, cancellationToken)))
        .RequireRateLimiting("forgot-password")
        .WithTags("Auth")
        .WithOpenApi();
}

app.Run();

static async Task ApplyMigrationsAsync(WebApplication app)
{
    const int maximumAttempts = 6;
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<BankingAppDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
        .CreateLogger("DatabaseMigration");

    for (var attempt = 1; attempt <= maximumAttempts; attempt++)
    {
        try
        {
            logger.LogInformation(
                "Applying database migrations (attempt {Attempt}/{MaximumAttempts}).",
                attempt,
                maximumAttempts);
            await dbContext.Database.MigrateAsync();
            logger.LogInformation("Database migrations applied successfully.");
            return;
        }
        catch (Exception exception) when (attempt < maximumAttempts)
        {
            var delay = TimeSpan.FromSeconds(Math.Min(attempt * 2, 10));
            logger.LogWarning(
                exception,
                "Database migration attempt failed. Retrying in {DelaySeconds} seconds.",
                delay.TotalSeconds);
            await Task.Delay(delay);
        }
    }
}

static bool IsAllowedOrigin(string origin, string[] allowedOrigins, bool isDevelopment)
{
    if (allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase))
    {
        return true;
    }

    if (!isDevelopment || !Uri.TryCreate(origin, UriKind.Absolute, out var uri))
    {
        return false;
    }

    return uri.Scheme is "http" or "https" &&
        uri.Host is "localhost" or "127.0.0.1";
}
