using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities
{
    public class CardRequest
    {
        public Guid Id { get; set; }

        public Guid UserId { get; set; }

        public string CardholderName { get; set; } = string.Empty;

        public string Currency { get; set; } = string.Empty;

        public string DocumentNumber { get; set; } = string.Empty;

        public string DeliveryAddress { get; set; } = string.Empty;

        public string Note { get; set; } = string.Empty;

        public CardRequestStatus Status { get; set; }

        public string? AdminNote { get; set; }

        public string? DocumentsRequestNote { get; set; }

        public DateTime? DocumentsRequestedAtUtc { get; set; }

        public Guid? ApprovedAccountId { get; set; }

        public Guid? ApprovedCardId { get; set; }

        public DateTime CreatedAtUtc { get; set; }

        public DateTime? ReviewedAtUtc { get; set; }

        public Guid? ReviewedByUserId { get; set; }

        public User User { get; set; } = null!;

        public Account? ApprovedAccount { get; set; }

        public BankCard? ApprovedCard { get; set; }

        public ICollection<CardRequestDocument> Documents { get; set; } = new List<CardRequestDocument>();
    }
}
