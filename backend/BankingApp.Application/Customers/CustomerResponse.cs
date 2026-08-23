using BankingApp.Domain.Enums;
using BankingApp.Application.Common.Models;

namespace BankingApp.Application.Customers
{
    public class CustomerResponse
    {
        public Guid Id { get; set; }

        public string FirstName { get; set; } = string.Empty;

        public string LastName { get; set; } = string.Empty;

        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string PhoneNumber { get; set; } = string.Empty;

        public CustomerStatus Status { get; set; }

        public int AccountCount { get; set; }

        public IReadOnlyCollection<CurrencyAmountResponse> Balances { get; set; } = [];

        public DateTime CreatedAtUtc { get; set; }
    }
}
