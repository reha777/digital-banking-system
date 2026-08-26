using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Transactions
{
    public class TransactionDocumentUploadRequest
    {
        [Required]
        public string FileName { get; set; } = string.Empty;

        [Required]
        public string ContentType { get; set; } = string.Empty;

        [Required]
        public byte[] Content { get; set; } = [];
        public Guid? DocumentTypeId { get; set; }
    }
}
