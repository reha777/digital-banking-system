using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions
{
    public class TransactionResponse
    {
        public Guid Id { get; set; }

        public Guid AccountId { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public string ReferenceNumber { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        public string Description { get; set; } = string.Empty;

        public TransactionStatus Status { get; set; }

        public DateTime CreatedAtUtc { get; set; }
    }
}
