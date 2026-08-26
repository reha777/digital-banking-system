using BankingApp.Application.Interfaces;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace BankingApp.Infrastructure.Services;

public interface ISmtpEmailTransport
{
    Task SendAsync(MimeMessage message, EmailOptions options, CancellationToken cancellationToken);
}

public sealed class MailKitSmtpEmailTransport : ISmtpEmailTransport
{
    public async Task SendAsync(
        MimeMessage message,
        EmailOptions options,
        CancellationToken cancellationToken)
    {
        using var client = new SmtpClient();
        var socketOptions = options.UseSsl
            ? SecureSocketOptions.SslOnConnect
            : SecureSocketOptions.Auto;
        await client.ConnectAsync(
            options.SmtpHost,
            options.SmtpPort,
            socketOptions,
            cancellationToken);
        await client.AuthenticateAsync(
            options.SmtpUsername,
            options.SmtpPassword,
            cancellationToken);
        await client.SendAsync(message, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);
    }
}

public sealed class SmtpEmailService(
    IOptions<EmailOptions> configured,
    ISmtpEmailTransport transport) : IEmailService
{
    private readonly EmailOptions options = configured.Value;

    public Task SendPasswordResetAsync(
        string recipientEmail,
        string token,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(options.FromName, options.FromAddress));
        message.To.Add(MailboxAddress.Parse(recipientEmail));
        message.Subject = "Reset your Digital Banking password";
        message.Body = new BodyBuilder
        {
            TextBody = BuildText(token),
            HtmlBody = BuildHtml(token),
        }.ToMessageBody();
        return transport.SendAsync(message, options, cancellationToken);
    }

    private static string BuildText(string token) =>
        $"Reset your Digital Banking password{Environment.NewLine}{Environment.NewLine}" +
        $"A password reset was requested for your account.{Environment.NewLine}{Environment.NewLine}" +
        $"Reset Code:{Environment.NewLine}{token}{Environment.NewLine}{Environment.NewLine}" +
        $"This code is valid for 30 minutes.{Environment.NewLine}" +
        "If you did not request a password reset, you can safely ignore this email.";

    private static string BuildHtml(string token) => $$"""
        <!doctype html>
        <html lang="en">
        <body style="margin:0;background:#f4f6fb;font-family:Arial,sans-serif;color:#161827">
          <div style="max-width:560px;margin:32px auto;padding:32px;background:#ffffff;border-radius:16px">
            <h1 style="margin:0 0 18px;font-size:24px">Reset your Digital Banking password</h1>
            <p>A password reset was requested for your account.</p>
            <p style="margin:24px 0 8px;font-size:13px;color:#667085">Reset Code</p>
            <div style="padding:16px;border-radius:10px;background:#f0f4ff;font-family:monospace;font-size:18px;word-break:break-all">{{token}}</div>
            <p style="margin-top:24px">This code is valid for 30 minutes.</p>
            <p style="color:#667085">If you did not request a password reset, you can safely ignore this email.</p>
          </div>
        </body>
        </html>
        """;
}
