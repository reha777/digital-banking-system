using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Customers
{
    public class CustomerQueryRequest : PagedRequest
    {
        public string? Search { get; set; }

        public CustomerStatus? Status { get; set; }
    }
}
