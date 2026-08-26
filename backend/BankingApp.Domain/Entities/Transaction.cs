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
        public Guid? TransactionCategoryId { get; set; }

        public string ReferenceNumber { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        public TransactionType Type { get; set; } = TransactionType.Transfer;

        public decimal? TransferAmount { get; set; }

        public string? TransferCurrency { get; set; }

        public decimal? DestinationAmount { get; set; }

        public string Description { get; set; } = string.Empty;

        public TransactionStatus Status { get; set; }

        public bool IsHighRiskReview { get; set; }

        public string? ReviewReason { get; set; }

        public string? DocumentsRequestNote { get; set; }

        public DateTime? DocumentsRequestedAtUtc { get; set; }

        public string? AdminNote { get; set; }

        public DateTime? ReviewedAtUtc { get; set; }

        public Guid? ReviewedByUserId { get; set; }

        public DateTime CreatedAtUtc { get; set; }

        public ICollection<TransactionDocument> Documents { get; set; } =
            new List<TransactionDocument>();
        public ReferenceDataItem? TransactionCategory { get; set; }
    }
}
