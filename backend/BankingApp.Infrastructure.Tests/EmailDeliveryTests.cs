using BankingApp.Api.Configuration;
using BankingApp.Application.Interfaces;
using BankingApp.Infrastructure.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MimeKit;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class EmailDeliveryTests
{
    [Fact]
    public async Task Development_provider_creates_complete_outbox_message()
    {
        var root = Path.Combine(Path.GetTempPath(), $"banking-email-{Guid.NewGuid():N}");
        try
        {
            var service = new DevelopmentEmailService(root);
            var expires = DateTime.UtcNow.AddMinutes(30);
            await service.SendPasswordResetAsync("customer@example.com", "reset-code", expires);

            var file = Assert.Single(Directory.GetFiles(
                Path.Combine(root, "development-email-outbox"),
                "password-reset-*.txt"));
            var content = await File.ReadAllTextAsync(file);
            Assert.Contains("customer@example.com", content);
            Assert.Contains("reset-code", content);
            Assert.Contains($"Expires: {expires:O}", content);
        }
        finally
        {
            if (Directory.Exists(root)) Directory.Delete(root, true);
        }
    }

    [Fact]
    public void Smtp_options_require_complete_configuration()
    {
        var result = new EmailOptionsValidator().Validate(
            null,
            new EmailOptions { Provider = "Smtp" });

        Assert.True(result.Failed);
        Assert.Contains("Email:SmtpHost", result.FailureMessage);
        Assert.Contains("Email:SmtpPassword", result.FailureMessage);
        Assert.Contains("Email:FromAddress", result.FailureMessage);
    }

    [Fact]
    public void Di_selects_development_and_smtp_providers()
    {
        using var development = BuildProvider(new Dictionary<string, string?>
        {
            ["Email:Provider"] = "Development",
        });
        Assert.IsType<DevelopmentEmailService>(development.GetRequiredService<IEmailService>());

        using var smtp = BuildProvider(CompleteSmtpConfiguration());
        Assert.IsType<SmtpEmailService>(smtp.GetRequiredService<IEmailService>());
    }

    [Fact]
    public void Production_rejects_development_provider()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Email:Provider"] = "Development",
            })
            .Build();

        var error = Assert.Throws<InvalidOperationException>(() =>
            new ServiceCollection().AddConfiguredEmailDelivery(
                configuration,
                Path.GetTempPath(),
                isProduction: true));
        Assert.Contains("cannot be used in Production", error.Message);
    }

    [Fact]
    public async Task Smtp_service_builds_html_and_plain_text_without_sending_network_email()
    {
        var options = new EmailOptions
        {
            Provider = "Smtp",
            SmtpHost = "smtp.example.com",
            SmtpPort = 587,
            SmtpUsername = "user",
            SmtpPassword = "secret",
            FromAddress = "no-reply@example.com",
            FromName = "Digital Banking",
        };
        var transport = new CapturingTransport();
        var service = new SmtpEmailService(Options.Create(options), transport);

        await service.SendPasswordResetAsync(
            "customer@example.com",
            "base64url-reset-code",
            DateTime.UtcNow.AddMinutes(30));

        var message = Assert.IsType<MimeMessage>(transport.Message);
        Assert.Equal("Reset your Digital Banking password", message.Subject);
        Assert.Contains("base64url-reset-code", message.TextBody);
        Assert.Contains("valid for 30 minutes", message.TextBody);
        Assert.Contains("base64url-reset-code", message.HtmlBody);
        Assert.DoesNotContain("secret", message.ToString());
    }

    private static ServiceProvider BuildProvider(
        Dictionary<string, string?> values)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
        var services = new ServiceCollection();
        services.AddConfiguredEmailDelivery(
            configuration,
            Path.GetTempPath(),
            isProduction: false);
        return services.BuildServiceProvider();
    }

    private static Dictionary<string, string?> CompleteSmtpConfiguration() => new()
    {
        ["Email:Provider"] = "Smtp",
        ["Email:SmtpHost"] = "smtp.example.com",
        ["Email:SmtpPort"] = "587",
        ["Email:SmtpUsername"] = "user",
        ["Email:SmtpPassword"] = "secret",
        ["Email:FromAddress"] = "no-reply@example.com",
        ["Email:FromName"] = "Digital Banking",
        ["Email:UseSsl"] = "false",
    };

    private sealed class CapturingTransport : ISmtpEmailTransport
    {
        public MimeMessage? Message { get; private set; }

        public Task SendAsync(
            MimeMessage message,
            EmailOptions options,
            CancellationToken cancellationToken)
        {
            Message = message;
            return Task.CompletedTask;
        }
    }
}
