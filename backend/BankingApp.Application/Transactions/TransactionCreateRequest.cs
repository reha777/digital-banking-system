using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Transactions
{
    public class TransactionCreateRequest
    {
        [Required]
        public Guid AccountId { get; set; }

        [Range(typeof(decimal), "-999999999999.99", "999999999999.99")]
        public decimal Amount { get; set; }

        [Required]
        [MaxLength(250)]
        public string Description { get; set; } = string.Empty;
    }
}
