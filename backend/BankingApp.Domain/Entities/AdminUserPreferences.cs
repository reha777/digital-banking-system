namespace BankingApp.Domain.Entities;

public class AdminUserPreferences
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string ThemeMode { get; set; } = "system";
    public string SidebarStyle { get; set; } = "expanded";
    public string DateFormat { get; set; } = "DD.MM.YYYY";
    public string TimeFormat { get; set; } = "24h";
    public string FirstDayOfWeek { get; set; } = "monday";
    public string NumberFormat { get; set; } = "1,234.56";
    public string Timezone { get; set; } = "Europe/Sarajevo";
    public int DefaultItemsPerPage { get; set; } = 10;
    public DateTime UpdatedAtUtc { get; set; }
}
