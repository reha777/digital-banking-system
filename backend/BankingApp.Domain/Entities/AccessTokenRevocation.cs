namespace BankingApp.Domain.Entities
{
    public class AccessTokenRevocation
    {
        public Guid Id { get; set; }

        public string TokenId { get; set; } = string.Empty;

        public Guid? UserId { get; set; }

        public DateTime ExpiresAtUtc { get; set; }

        public DateTime RevokedAtUtc { get; set; }
    }
}
