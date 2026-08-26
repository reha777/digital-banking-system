using BankingApp.Worker;
using Xunit;

namespace BankingApp.Worker.Tests;

public sealed class RabbitMqConsumerOptionsValidatorTests
{
    [Fact]
    public void Fully_configured_options_are_accepted()
    {
        Assert.True(new RabbitMqConsumerOptionsValidator()
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
        typeof(RabbitMqConsumerOptions).GetProperty(setting)!
            .SetValue(options, string.Empty);

        var result = new RabbitMqConsumerOptionsValidator().Validate(null, options);

        Assert.True(result.Failed);
        Assert.Contains($"RabbitMq:{setting}", result.FailureMessage);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(70000)]
    public void Out_of_range_ports_are_rejected(int port)
    {
        var options = Configured();
        options.Port = port;

        var result = new RabbitMqConsumerOptionsValidator().Validate(null, options);

        Assert.True(result.Failed);
        Assert.Contains("RabbitMq:Port", result.FailureMessage);
    }

    private static RabbitMqConsumerOptions Configured() => new()
    {
        Host = "rabbitmq",
        Port = 5672,
        UserName = "bankingapp",
        Password = "secret",
        AuditArchiveQueue = "banking.audit-archive.v1",
        ReportGenerationQueue = "banking.report-generation.v1"
    };
}
