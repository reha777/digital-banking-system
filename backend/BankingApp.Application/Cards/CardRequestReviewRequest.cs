using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Cards
{
    public class CardRequestReviewRequest
    {
        [StringLength(500)]
        public string? AdminNote { get; set; }
    }
}
