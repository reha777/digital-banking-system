using BankingApp.Application.Interfaces;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public sealed class UserSessionRevocationService(BankingAppDbContext dbContext)
    : IUserSessionRevocationService
{
    public async Task RevokeAllRefreshTokensAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var activeTokens = await dbContext.RefreshTokens
            .Where(token =>
                token.UserId == userId &&
                token.RevokedAtUtc == null &&
                token.ExpiresAtUtc > now)
            .ToListAsync(cancellationToken);

        foreach (var token in activeTokens)
        {
            token.RevokedAtUtc = now;
        }
    }
}
