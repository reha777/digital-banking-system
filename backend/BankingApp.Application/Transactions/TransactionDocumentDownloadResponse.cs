namespace BankingApp.Application.Transactions
{
    public class TransactionDocumentDownloadResponse
    {
        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = string.Empty;

        public byte[] Content { get; set; } = [];
    }
}
