namespace BankingApp.Application.Transactions
{
    public class TransactionSummaryResponse
    {
        public int TotalTransactions { get; set; }

        public int CompletedTransactions { get; set; }

        public decimal TotalTransferred { get; set; }
    }
}
