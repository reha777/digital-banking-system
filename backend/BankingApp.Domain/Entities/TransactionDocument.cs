namespace BankingApp.Domain.Entities
{
    public class TransactionDocument
    {
        public Guid Id { get; set; }

        public Guid TransactionId { get; set; }
        public Guid? DocumentTypeId { get; set; }

        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public long SizeBytes { get; set; }

        public byte[] Content { get; set; } = [];

        public DateTime UploadedAtUtc { get; set; }

        public Transaction Transaction { get; set; } = null!;
        public ReferenceDataItem? DocumentType { get; set; }
    }
}
