namespace BankingApp.Application.Cards
{
    public class CardRequestDocumentDownloadResponse
    {
        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public byte[] Content { get; set; } = [];
    }
}
