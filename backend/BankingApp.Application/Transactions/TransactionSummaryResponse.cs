using BankingApp.Application.Common.Models;

namespace BankingApp.Application.Transactions
{
    public class TransactionSummaryResponse
    {
        public int TotalTransactions { get; set; }

        public int CompletedTransactions { get; set; }

        public IReadOnlyCollection<CurrencyAmountResponse> TransferredByCurrency { get; set; } = [];
    }
}
