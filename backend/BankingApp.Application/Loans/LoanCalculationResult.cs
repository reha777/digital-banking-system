namespace BankingApp.Application.Loans;

public class LoanCalculationResult
{
    public decimal Principal { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal MonthlyPayment { get; set; }
    public decimal TotalInterest { get; set; }
    public decimal TotalRepayment { get; set; }
    public DateTime FirstPaymentDate { get; set; }
    public IReadOnlyCollection<LoanScheduleItemResponse> Schedule { get; set; } = [];
}

public class LoanScheduleItemResponse
{
    public int InstallmentNumber { get; set; }
    public DateTime DueDate { get; set; }
    public decimal ScheduledAmount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal RemainingPrincipalAfter { get; set; }
}
