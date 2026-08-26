namespace BankingApp.Worker;

public sealed class AuditArchiveOptions
{
    public const string SectionName = "AuditArchive";
    public string OutputDirectory { get; set; } = "audit-archives";
}
