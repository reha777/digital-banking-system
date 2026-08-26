using Microsoft.Extensions.Options;

namespace BankingApp.Infrastructure.Services;

public sealed class EmailOptions
{
    public const string SectionName = "Email";
    public string Provider { get; set; } = "Development";
    public string SmtpHost { get; set; } = string.Empty;
    public int SmtpPort { get; set; } = 587;
    public string SmtpUsername { get; set; } = string.Empty;
    public string SmtpPassword { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = "Digital Banking";
    public bool UseSsl { get; set; }
}

public sealed class EmailOptionsValidator : IValidateOptions<EmailOptions>
{
    public ValidateOptionsResult Validate(string? name, EmailOptions options)
    {
        if (options.Provider.Equals("Development", StringComparison.OrdinalIgnoreCase))
        {
            return ValidateOptionsResult.Success;
        }

        if (!options.Provider.Equals("Smtp", StringComparison.OrdinalIgnoreCase))
        {
            return ValidateOptionsResult.Fail(
                "Email:Provider must be either 'Development' or 'Smtp'.");
        }

        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(options.SmtpHost)) missing.Add("Email:SmtpHost");
        if (options.SmtpPort is < 1 or > 65535) missing.Add("Email:SmtpPort");
        if (string.IsNullOrWhiteSpace(options.SmtpUsername)) missing.Add("Email:SmtpUsername");
        if (string.IsNullOrWhiteSpace(options.SmtpPassword)) missing.Add("Email:SmtpPassword");
        if (string.IsNullOrWhiteSpace(options.FromAddress)) missing.Add("Email:FromAddress");
        if (string.IsNullOrWhiteSpace(options.FromName)) missing.Add("Email:FromName");

        return missing.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(
                $"SMTP email provider configuration is incomplete. Missing or invalid: {string.Join(", ", missing)}.");
    }
}
