using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Auth
{
    public class RefreshTokenRequest
    {
        [Required]
        public string RefreshToken { get; set; } = string.Empty;
    }
}
