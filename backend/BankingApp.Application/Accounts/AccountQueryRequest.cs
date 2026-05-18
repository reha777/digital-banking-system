using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Accounts
{
    public class AccountQueryRequest : PagedRequest
    {
        public string? Search { get; set; }

        public AccountType? AccountType { get; set; }

        public string? Currency { get; set; }
    }
}
