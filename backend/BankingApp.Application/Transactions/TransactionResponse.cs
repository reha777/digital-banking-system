using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions
{
    public class TransactionResponse
    {
        public Guid Id { get; set; }

        public Guid AccountId { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public Guid? SourceAccountId { get; set; }

        public Guid? DestinationAccountId { get; set; }

        public string? SourceAccountNumber { get; set; }

        public string? DestinationAccountNumber { get; set; }

        public string? SourceCustomerName { get; set; }

        public string? DestinationCustomerName { get; set; }

        public string ReferenceNumber { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        public string Description { get; set; } = string.Empty;

        public TransactionStatus Status { get; set; }

        public DateTime CreatedAtUtc { get; set; }
    }
}
