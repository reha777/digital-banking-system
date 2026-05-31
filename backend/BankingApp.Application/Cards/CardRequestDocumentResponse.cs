namespace BankingApp.Application.Cards
{
    public class CardRequestDocumentResponse
    {
        public Guid Id { get; set; }

        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public long SizeBytes { get; set; }

        public DateTime UploadedAtUtc { get; set; }
    }
}
