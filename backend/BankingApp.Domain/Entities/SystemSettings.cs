namespace BankingApp.Domain.Entities;

public class SystemSettings
{
    public int Id { get; set; }
    public string SystemName { get; set; } = "Digital Banking System";
    public string SystemShortName { get; set; } = "DBS";
    public string CompanyName { get; set; } = "Your Bank Ltd.";
    public string CompanyEmail { get; set; } = "support@yourbank.com";
    public string CompanyPhone { get; set; } = "+387 33 123 456";
    public string Timezone { get; set; } = "Europe/Sarajevo";
    public int SessionTimeoutMinutes { get; set; } = 30;
    public int AutoLogoutWarningMinutes { get; set; } = 5;
    public bool EnableDataCaching { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public Guid? UpdatedByUserId { get; set; }
}
