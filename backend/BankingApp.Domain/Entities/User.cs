using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities
{
    public class User
    {
        public Guid Id { get; set; }

        public string FirstName { get; set; } = string.Empty;

        public string LastName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string PhoneNumber { get; set; } = string.Empty;

        public string PasswordHash { get; set; } = string.Empty;

        public byte[]? ProfilePhoto { get; set; }

        public string? ProfilePhotoContentType { get; set; }

        public DateTime? ProfilePhotoUpdatedAtUtc { get; set; }

        public string Role { get; set; } = string.Empty;

        public CustomerStatus Status { get; set; } = CustomerStatus.Active;

        public bool IsDeleted { get; set; }

        public DateTime? DeletedAtUtc { get; set; }

        public DateTime CreatedAtUtc { get; set; }

        public ICollection<Account> Accounts { get; set; } = new List<Account>();

        public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();

        public ICollection<CardRequest> CardRequests { get; set; } = new List<CardRequest>();

        public ICollection<LoanApplication> LoanApplications { get; set; } = new List<LoanApplication>();

        public ICollection<Loan> Loans { get; set; } = new List<Loan>();
    }
}
