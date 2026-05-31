using BankingApp.Domain.Enums;

namespace BankingApp.Application.Cards
{
    public class CardRequestResponse
    {
        public Guid Id { get; set; }

        public Guid UserId { get; set; }

        public string CustomerName { get; set; } = string.Empty;

        public string CustomerEmail { get; set; } = string.Empty;

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

        public string? ApprovedAccountNumber { get; set; }

        public string? ApprovedMaskedCardNumber { get; set; }

        public DateTime CreatedAtUtc { get; set; }

        public DateTime? ReviewedAtUtc { get; set; }

        public IReadOnlyCollection<CardRequestDocumentResponse> Documents { get; set; } =
            [];
    }
}
