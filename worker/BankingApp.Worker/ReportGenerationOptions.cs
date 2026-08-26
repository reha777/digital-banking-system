namespace BankingApp.Worker;

public sealed class ReportGenerationOptions
{
    public const string SectionName = "Reports";
    public string OutputDirectory { get; set; } = "reports";
    public int MaxRows { get; set; } = 5000;
}
