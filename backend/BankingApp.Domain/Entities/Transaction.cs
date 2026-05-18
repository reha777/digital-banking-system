using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities
{
    public class Transaction
    {
        public Guid Id { get; set; }

        public Guid AccountId { get; set; }

        public Account Account { get; set; } = null!;

        public Guid? SourceAccountId { get; set; }

        public Guid? DestinationAccountId { get; set; }

        public string ReferenceNumber { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        public string Description { get; set; } = string.Empty;

        public TransactionStatus Status { get; set; }

        public DateTime CreatedAtUtc { get; set; }
    }
}
