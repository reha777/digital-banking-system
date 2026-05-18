using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions
{
    public class MoneyTransferResponse
    {
        public string ReferenceNumber { get; set; } = string.Empty;

        public TransactionStatus Status { get; set; }

        public decimal Amount { get; set; }

        public string Currency { get; set; } = string.Empty;

        public TransferAccountResponse SourceAccount { get; set; } = new();

        public TransferAccountResponse DestinationAccount { get; set; } = new();

        public TransactionResponse DebitTransaction { get; set; } = new();

        public TransactionResponse CreditTransaction { get; set; } = new();

        public DateTime CreatedAtUtc { get; set; }
    }

    public class TransferAccountResponse
    {
        public Guid Id { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public decimal Balance { get; set; }

        public string Currency { get; set; } = string.Empty;
    }
}
