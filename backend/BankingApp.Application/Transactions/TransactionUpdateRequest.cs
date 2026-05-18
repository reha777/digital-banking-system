using System.ComponentModel.DataAnnotations;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions
{
    public class TransactionUpdateRequest
    {
        [Required]
        [MaxLength(250)]
        public string Description { get; set; } = string.Empty;

        [Required]
        public TransactionStatus Status { get; set; }
    }
}
