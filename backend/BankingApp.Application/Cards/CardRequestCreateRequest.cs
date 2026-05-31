using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Cards
{
    public class CardRequestCreateRequest
    {
        [Required]
        [StringLength(160)]
        public string CardholderName { get; set; } = string.Empty;

        [Required]
        [StringLength(3, MinimumLength = 3)]
        public string Currency { get; set; } = string.Empty;

        [Required]
        [StringLength(80)]
        public string DocumentNumber { get; set; } = string.Empty;

        [Required]
        [StringLength(250)]
        public string DeliveryAddress { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Note { get; set; }
    }
}
