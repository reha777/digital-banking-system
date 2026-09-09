using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Loans;

public sealed class LoanDocumentResponse
{
    public Guid Id { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public DateTime UploadedAtUtc { get; set; }
}

public sealed class LoanDocumentUploadRequest
{
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public byte[] Content { get; set; } = [];
}

public sealed class LoanDocumentDownloadResponse
{
    public byte[] Content { get; set; } = [];
    public string ContentType { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
}

public sealed class LoanDocumentRequest
{
    [Required, StringLength(120)]
    public string Description { get; set; } = string.Empty;
    [Required, StringLength(500)]
    public string Message { get; set; } = string.Empty;
}
