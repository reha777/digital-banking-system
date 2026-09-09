using BankingApp.Domain.Enums;

namespace BankingApp.Application.Accounts
{
    public class AccountResponse
    {
        public Guid Id { get; set; }

        public string AccountNumber { get; set; } = string.Empty;

        public Guid AccountTypeId { get; set; }
        public string AccountTypeCode { get; set; } = string.Empty;
        public string AccountTypeName { get; set; } = string.Empty;
        public string AccountType => AccountTypeName;

        public AccountStatus Status { get; set; }

        public decimal Balance { get; set; }

        public string Currency { get; set; } = string.Empty;

        public DateTime CreatedAtUtc { get; set; }
    }
}
