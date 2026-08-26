using System.Text;
using BankingApp.Application.Interfaces;

namespace BankingApp.Infrastructure.Services;

public sealed class DevelopmentEmailService(string contentRootPath) : IEmailService
{
    public async Task SendPasswordResetAsync(string recipientEmail, string token, DateTime expiresAtUtc, CancellationToken cancellationToken = default)
    {
        var directory = Path.Combine(contentRootPath, "development-email-outbox"); Directory.CreateDirectory(directory);
        var safeId = Guid.NewGuid().ToString("N"); var path = Path.Combine(directory, $"password-reset-{safeId}.txt");
        var content = $"To: {recipientEmail}{Environment.NewLine}Subject: Reset your Digital Banking password{Environment.NewLine}{Environment.NewLine}A password reset was requested for your account.{Environment.NewLine}{Environment.NewLine}Reset Code:{Environment.NewLine}{token}{Environment.NewLine}{Environment.NewLine}This code is valid for 30 minutes.{Environment.NewLine}Expires: {expiresAtUtc:O}{Environment.NewLine}{Environment.NewLine}If you did not request a password reset, you can safely ignore this email.";
        await File.WriteAllTextAsync(path, content, Encoding.UTF8, cancellationToken);
    }
}
