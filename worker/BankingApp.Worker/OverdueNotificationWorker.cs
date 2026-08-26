using Microsoft.Extensions.Options;

namespace BankingApp.Worker;

public sealed class OverdueNotificationWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<NotificationOptions> options,
    ILogger<OverdueNotificationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = TimeSpan.FromSeconds(Math.Max(5, options.Value.OverdueCheckIntervalSeconds));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopeFactory.CreateAsyncScope();
                var count = await scope.ServiceProvider
                    .GetRequiredService<OverdueNotificationScanner>()
                    .ScanAsync(stoppingToken);
                logger.LogInformation("Overdue loan notification scan inspected {Count} installments.", count);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Overdue loan notification scan failed.");
            }

            await Task.Delay(interval, stoppingToken);
        }
    }
}
