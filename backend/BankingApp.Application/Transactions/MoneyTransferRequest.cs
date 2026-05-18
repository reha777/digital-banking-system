using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Transactions
{
    public class MoneyTransferRequest
    {
        [Required]
        public Guid SourceAccountId { get; set; }

        [Required]
        [MaxLength(34)]
        public string DestinationAccountNumber { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        [MaxLength(250)]
        public string? Description { get; set; }
    }
}
