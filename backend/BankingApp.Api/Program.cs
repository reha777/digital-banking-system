using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using BankingApp.Api.Configuration;
using BankingApp.Api.Middleware;
using BankingApp.Api.Services;
using BankingApp.Application.Interfaces;
using BankingApp.Infrastructure.Authentication;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

EnvFileLoader.Load();

var builder = WebApplication.CreateBuilder(args);
const string CorsPolicyName = "ConfiguredOrigins";

builder.Services.AddOpenApi();
builder.Services.AddControllers();
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
                }
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IAccountService, AccountService>();
builder.Services.AddScoped<ITransactionService, TransactionService>();
builder.Services.AddScoped<IAdminCustomerService, AdminCustomerService>();
builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
builder.Services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseHttpsRedirection();
app.UseCors(CorsPolicyName);
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

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
