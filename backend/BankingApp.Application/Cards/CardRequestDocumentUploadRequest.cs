using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Cards
{
    public class CardRequestDocumentUploadRequest
    {
        [Required]
        [StringLength(180)]
        public string FileName { get; set; } = string.Empty;

        [Required]
        [StringLength(120)]
        public string ContentType { get; set; } = string.Empty;

        [Required]
        public byte[] Content { get; set; } = [];
    }
}
