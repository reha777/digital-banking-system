using Microsoft.Extensions.Options;

namespace BankingApp.Infrastructure.Authentication;

public sealed class DemoAuthOptions
{
    public const string SectionName = "DemoAuth";
    public bool Enabled { get; set; }
    public string CustomerPrimaryAccountEmail { get; set; } = string.Empty;
    public string CustomerSecondaryAccountEmail { get; set; } = string.Empty;
    public string AdminAccountEmail { get; set; } = string.Empty;
}

public sealed class DemoAuthOptionsValidator(bool isProduction)
    : IValidateOptions<DemoAuthOptions>
{
    public ValidateOptionsResult Validate(string? name, DemoAuthOptions options)
    {
        if (!options.Enabled) return ValidateOptionsResult.Success;
        if (isProduction)
        {
            return ValidateOptionsResult.Fail(
                "DemoAuth cannot be enabled in Production.");
        }

        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(options.CustomerPrimaryAccountEmail))
            missing.Add("DemoAuth:CustomerPrimaryAccountEmail");
        if (string.IsNullOrWhiteSpace(options.CustomerSecondaryAccountEmail))
            missing.Add("DemoAuth:CustomerSecondaryAccountEmail");
        if (string.IsNullOrWhiteSpace(options.AdminAccountEmail))
            missing.Add("DemoAuth:AdminAccountEmail");
        return missing.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(
                $"DemoAuth configuration is incomplete. Missing: {string.Join(", ", missing)}.");
    }
}
