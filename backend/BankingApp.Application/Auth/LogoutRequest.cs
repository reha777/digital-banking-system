using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Auth
{
    public class LogoutRequest
    {
        public string? AccessToken { get; set; }

        [Required]
        public string RefreshToken { get; set; } = string.Empty;
    }
}
