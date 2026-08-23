using BankingApp.Application.Common.Models;
using BankingApp.Application.Transactions;

namespace BankingApp.Application.Dashboard;

public class AdminDashboardResponse
{
    public int PeriodDays { get; set; }
    public IReadOnlyCollection<TransactionActivityPointResponse> TransactionActivity { get; set; } = [];
    public int TotalCustomers { get; set; }
    public int ActiveCustomers { get; set; }
    public int TotalTransactions { get; set; }
    public int CompletedTransactions { get; set; }
    public int FailedTransactions { get; set; }
    public IReadOnlyCollection<CurrencyAmountResponse> TransferredByCurrency { get; set; } = [];
    public int PendingTransactionReviews { get; set; }
    public int DocumentsRequested { get; set; }
    public int PendingCardRequests { get; set; }
    public int PendingLoanApplications { get; set; }
    public int ActiveLoans { get; set; }
    public int LoansWithOverduePayments { get; set; }
    public IReadOnlyCollection<TransactionResponse> RecentTransactions { get; set; } = [];
}

public class TransactionActivityPointResponse
{
    public DateTime DateUtc { get; set; }
    public int TransactionCount { get; set; }
}
