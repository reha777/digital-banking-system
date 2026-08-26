using BankingApp.Infrastructure.Messaging;
using BankingApp.Worker;
using Xunit;

namespace BankingApp.Worker.Tests;

public sealed class MessageRetryPolicyTests
{
    [Fact]
    public void Backoff_grows_exponentially_and_stays_bounded()
    {
        var delays = Enumerable.Range(1, 6)
            .Select(attempt => ExponentialBackoff.GetDelay(attempt).TotalSeconds)
            .ToArray();

        Assert.Equal([1d, 2d, 4d, 8d, 8d, 8d], delays);
    }

    [Fact]
    public void Backoff_never_returns_an_immediate_retry()
    {
        for (var attempt = 1; attempt <= 64; attempt++)
        {
            Assert.InRange(
                ExponentialBackoff.GetDelay(attempt),
                TimeSpan.FromSeconds(1),
                TimeSpan.FromSeconds(8));
        }
    }

    [Fact]
    public void Transient_failures_are_retried_with_growing_delays_then_rejected()
    {
        var policy = new MessageRetryPolicy();

        var first = policy.RegisterFailure("job-1");
        var second = policy.RegisterFailure("job-1");
        var third = policy.RegisterFailure("job-1");
        var fourth = policy.RegisterFailure("job-1");

        Assert.True(first.ShouldRetry);
        Assert.True(second.ShouldRetry);
        Assert.True(third.ShouldRetry);
        Assert.False(fourth.ShouldRetry);
        Assert.Equal(
            [1d, 2d, 4d, 8d],
            new[] { first, second, third, fourth }
                .Select(decision => decision.Delay.TotalSeconds));
    }

    [Fact]
    public void Attempts_are_tracked_per_message_and_do_not_leak_across_messages()
    {
        var policy = new MessageRetryPolicy();

        policy.RegisterFailure("job-1");
        policy.RegisterFailure("job-1");
        var other = policy.RegisterFailure("job-2");

        Assert.Equal(1, other.Attempt);
    }

    [Fact]
    public void Clearing_a_message_resets_its_attempt_counter()
    {
        var policy = new MessageRetryPolicy();

        policy.RegisterFailure("job-1");
        policy.RegisterFailure("job-1");
        policy.Clear("job-1");

        Assert.Equal(1, policy.RegisterFailure("job-1").Attempt);
    }
}
