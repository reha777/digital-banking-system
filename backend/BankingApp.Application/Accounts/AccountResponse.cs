using BankingApp.Domain.Enums;

namespace BankingApp.Application.Accounts
{
    public class AccountResponse
    {
        public Guid Id { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public AccountType AccountType { get; set; }

        public decimal Balance { get; set; }

        public string Currency { get; set; } = string.Empty;

        public DateTime CreatedAtUtc { get; set; }
    }
}
