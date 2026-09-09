using BankingApp.Application.Common.Pagination;

namespace BankingApp.Application.Accounts
{
    public class AccountQueryRequest : PagedRequest
    {
        public string? Search { get; set; }

        public Guid? AccountTypeId { get; set; }
        public string? AccountTypeCode { get; set; }

        public string? Currency { get; set; }
    }
}
