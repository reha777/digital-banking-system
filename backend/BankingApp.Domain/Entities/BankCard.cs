using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities
{
    public class BankCard
    {
        public Guid Id { get; set; }

        public Guid AccountId { get; set; }

        public string CardNumber { get; set; } = string.Empty;

        public string CardholderName { get; set; } = string.Empty;

        // The CVV is deliberately not persisted. It is generated during card
        // issuance, returned once in the issue result, and is not retrievable
        // afterwards. See CardIssueResult.
        public DateTime ExpiryDate { get; set; }

        public CardBrand Brand { get; set; }

        public CardStatus Status { get; set; }

        public DateTime CreatedAtUtc { get; set; }

        public Account Account { get; set; } = null!;
    }
}
