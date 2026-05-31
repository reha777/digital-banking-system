using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Cards
{
    public class CardRequestQueryRequest : PagedRequest
    {
        public string? Search { get; set; }

        public CardRequestStatus? Status { get; set; }
    }
}
