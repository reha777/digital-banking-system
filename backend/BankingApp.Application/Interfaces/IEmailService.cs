namespace BankingApp.Application.Interfaces;

public interface IEmailService
{
    Task SendPasswordResetAsync(string recipientEmail, string token, DateTime expiresAtUtc, CancellationToken cancellationToken = default);
}
