using BankingApp.Domain.Enums;

namespace BankingApp.Application.Cards
{
    public class CardResponse
    {
        public Guid Id { get; set; }

        public Guid AccountId { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public string CardNumber { get; set; } = string.Empty;

        public string MaskedCardNumber { get; set; } = string.Empty;

        public string CardholderName { get; set; } = string.Empty;

        public string Cvv { get; set; } = string.Empty;

        public DateTime ExpiryDate { get; set; }

        public CardBrand Brand { get; set; }

        public CardStatus Status { get; set; }

        public decimal Balance { get; set; }

        public string Currency { get; set; } = string.Empty;

        public DateTime CreatedAtUtc { get; set; }
    }
}
