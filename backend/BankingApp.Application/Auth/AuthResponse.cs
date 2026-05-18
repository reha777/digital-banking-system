namespace BankingApp.Application.Auth
{
    public class AuthResponse
    {
        public string Token { get; set; } = string.Empty;

        public DateTime TokenExpiresAtUtc { get; set; }

        public string RefreshToken { get; set; } = string.Empty;

        public DateTime RefreshTokenExpiresAtUtc { get; set; }

        public UserResponse User { get; set; } = new();
    }
}
