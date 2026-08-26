namespace BankingApp.Infrastructure.Messaging;

public static class ExponentialBackoff
{
    public static TimeSpan GetDelay(int attempt, int maximumSeconds = 8)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(attempt, 1);
        ArgumentOutOfRangeException.ThrowIfLessThan(maximumSeconds, 1);
        var exponent = Math.Min(attempt - 1, 30);
        return TimeSpan.FromSeconds(Math.Min(1L << exponent, maximumSeconds));
    }
}
