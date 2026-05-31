using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Cards
{
    public class CardRequestDocumentsRequest
    {
        [StringLength(500)]
        public string? AdminNote { get; set; }
    }
}
