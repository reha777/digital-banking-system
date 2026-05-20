namespace BankingApp.Application.Customers
{
    public class CustomerSummaryResponse
    {
        public int TotalCustomers { get; set; }

        public int ActiveCustomers { get; set; }

        public int InactiveCustomers { get; set; }

        public int BlockedCustomers { get; set; }
    }
}
