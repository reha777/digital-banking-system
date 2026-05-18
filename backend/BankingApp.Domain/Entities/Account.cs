using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities
{
    public class Account
    {
        public Guid Id { get; set; }

        public Guid UserId { get; set; }

        public User User { get; set; } = null!;

        public string AccountNumber { get; set; } = string.Empty;

        public AccountType AccountType { get; set; }

        public decimal Balance { get; set; }

        public string Currency { get; set; } = string.Empty;

        public DateTime CreatedAtUtc { get; set; }

        public ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
    }
}
