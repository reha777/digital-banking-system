using System.Collections.Concurrent;
using BankingApp.Infrastructure.Messaging;

namespace BankingApp.Worker;

public sealed class MessageRetryPolicy(int maximumAttempts = 4)
{
    private readonly ConcurrentDictionary<string, int> attempts = new();

    public MessageRetryDecision RegisterFailure(string messageKey)
    {
        var attempt = attempts.AddOrUpdate(messageKey, 1, (_, current) => current + 1);
        return new MessageRetryDecision(
            attempt,
            attempt < maximumAttempts,
            ExponentialBackoff.GetDelay(attempt));
    }

    public void Clear(string messageKey) => attempts.TryRemove(messageKey, out _);
}

public sealed record MessageRetryDecision(
    int Attempt,
    bool ShouldRetry,
    TimeSpan Delay);
