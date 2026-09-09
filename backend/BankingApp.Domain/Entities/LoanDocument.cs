namespace BankingApp.Domain.Entities;

public class LoanDocument
{
    public Guid Id { get; set; }
    public Guid LoanApplicationId { get; set; }
    public Guid UploadedByUserId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public byte[] Content { get; set; } = [];
    public DateTime UploadedAtUtc { get; set; }
    public LoanApplication LoanApplication { get; set; } = null!;
    public User UploadedByUser { get; set; } = null!;
}
