namespace BankingApp.Application.Loans;

public class LoanQuoteResponse
{
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public decimal Principal { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal MonthlyPayment { get; set; }
    public decimal TotalInterest { get; set; }
    public decimal TotalRepayment { get; set; }
    public DateTime FirstPaymentDate { get; set; }
    public IReadOnlyCollection<LoanScheduleItemResponse> Schedule { get; set; } = [];
}
