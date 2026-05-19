using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Transactions
{
    public class TransactionQueryRequest : PagedRequest
    {
        public Guid? AccountId { get; set; }

        public string? Search { get; set; }

        public TransactionStatus? Status { get; set; }

        public DateTime? DateFrom { get; set; }

        public DateTime? DateTo { get; set; }
    }
}
