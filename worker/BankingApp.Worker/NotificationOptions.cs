namespace BankingApp.Worker;

public sealed class NotificationOptions
{
    public const string SectionName = "Notifications";
    public int OverdueCheckIntervalSeconds { get; set; } = 300;
}
