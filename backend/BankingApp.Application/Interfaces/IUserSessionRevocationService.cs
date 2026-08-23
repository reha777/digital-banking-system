namespace BankingApp.Application.Interfaces;

public interface IUserSessionRevocationService
{
    Task RevokeAllRefreshTokensAsync(
        Guid userId,
        CancellationToken cancellationToken = default);
}
