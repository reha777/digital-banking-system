using System.ComponentModel.DataAnnotations;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Accounts
{
    public class AccountCreateRequest
    {
        [Required]
        [MaxLength(34)]
        public string AccountNumber { get; set; } = string.Empty;

        [Required]
        public AccountType AccountType { get; set; }

        [Range(0, double.MaxValue)]
        public decimal OpeningBalance { get; set; }

        [Required]
        [StringLength(3, MinimumLength = 3)]
        public string Currency { get; set; } = string.Empty;
    }
}
