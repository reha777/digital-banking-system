using BankingApp.Infrastructure.Messaging;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class RabbitMqOptionsValidatorTests
{
    [Fact]
    public void Fully_configured_options_are_accepted()
    {
        Assert.True(new RabbitMqOptionsValidator()
            .Validate(null, Configured())
            .Succeeded);
    }

    [Theory]
    [InlineData("Host")]
    [InlineData("UserName")]
    [InlineData("Password")]
    [InlineData("AuditArchiveQueue")]
    [InlineData("ReportGenerationQueue")]
    public void Missing_required_values_fail_fast_with_the_setting_name(string setting)
    {
        var options = Configured();
        typeof(RabbitMqOptions).GetProperty(setting)!.SetValue(options, string.Empty);

        var result = new RabbitMqOptionsValidator().Validate(null, options);

        Assert.True(result.Failed);
        Assert.Contains($"RabbitMq:{setting}", result.FailureMessage);
    }

    [Fact]
    public void Options_do_not_silently_fall_back_to_guest_credentials()
    {
        var defaults = new RabbitMqOptions();

        Assert.Empty(defaults.Host);
        Assert.Empty(defaults.UserName);
        Assert.Empty(defaults.Password);
        Assert.True(new RabbitMqOptionsValidator().Validate(null, defaults).Failed);
    }

    private static RabbitMqOptions Configured() => new()
    {
        Host = "rabbitmq",
        Port = 5672,
        UserName = "bankingapp",
        Password = "secret",
        AuditArchiveQueue = "banking.audit-archive.v1",
        ReportGenerationQueue = "banking.report-generation.v1"
    };
}
