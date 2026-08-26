using BankingApp.Application.Interfaces;
using BankingApp.Infrastructure.Services;
using Microsoft.Extensions.Options;

namespace BankingApp.Api.Configuration;

public static class EmailServiceRegistration
{
    public static IServiceCollection AddConfiguredEmailDelivery(
        this IServiceCollection services,
        IConfiguration configuration,
        string contentRootPath,
        bool isProduction)
    {
        services.AddOptions<EmailOptions>()
            .Bind(configuration.GetSection(EmailOptions.SectionName))
            .ValidateOnStart();
        services.AddSingleton<IValidateOptions<EmailOptions>, EmailOptionsValidator>();

        var provider = configuration[$"{EmailOptions.SectionName}:Provider"];
        if (string.IsNullOrWhiteSpace(provider))
        {
            throw new InvalidOperationException("Email:Provider is not configured.");
        }
        if (provider.Equals("Development", StringComparison.OrdinalIgnoreCase))
        {
            if (isProduction)
            {
                throw new InvalidOperationException(
                    "The Development email provider cannot be used in Production.");
            }
            services.AddSingleton<IEmailService>(
                new DevelopmentEmailService(contentRootPath));
        }
        else if (provider.Equals("Smtp", StringComparison.OrdinalIgnoreCase))
        {
            services.AddSingleton<ISmtpEmailTransport, MailKitSmtpEmailTransport>();
            services.AddSingleton<IEmailService, SmtpEmailService>();
        }
        else
        {
            throw new InvalidOperationException(
                "Email:Provider must be either 'Development' or 'Smtp'.");
        }

        return services;
    }
}
