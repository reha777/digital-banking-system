namespace BankingApp.Application.Cards
{
    public class CardRequestSummaryResponse
    {
        public int TotalRequests { get; set; }

        public int PendingRequests { get; set; }

        public int ApprovedRequests { get; set; }

        public int RejectedRequests { get; set; }

        public int DocumentsRequestedRequests { get; set; }
    }
}
