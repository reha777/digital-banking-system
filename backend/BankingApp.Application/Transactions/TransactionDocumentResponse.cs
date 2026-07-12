namespace BankingApp.Application.Transactions
{
    public class TransactionDocumentResponse
    {
        public Guid Id { get; set; }

        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public long SizeBytes { get; set; }

        public DateTime UploadedAtUtc { get; set; }
    }
}
