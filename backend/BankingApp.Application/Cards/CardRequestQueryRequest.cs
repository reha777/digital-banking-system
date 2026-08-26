using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Cards
{
    public class CardRequestQueryRequest : PagedRequest
    {
        public string? Search { get; set; }

        public Guid? CustomerId { get; set; }

        public CardRequestStatus? Status { get; set; }

        public DateTime? DateFromUtc { get; set; }

        public DateTime? DateToUtc { get; set; }
    }
}
