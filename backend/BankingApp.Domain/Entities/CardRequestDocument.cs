namespace BankingApp.Domain.Entities
{
    public class CardRequestDocument
    {
        public Guid Id { get; set; }

        public Guid CardRequestId { get; set; }

        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public long SizeBytes { get; set; }

        public byte[] Content { get; set; } = [];

        public DateTime UploadedAtUtc { get; set; }

        public CardRequest CardRequest { get; set; } = null!;
    }
}
