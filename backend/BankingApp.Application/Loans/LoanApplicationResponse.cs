using BankingApp.Domain.Enums;

namespace BankingApp.Application.Loans;

public class LoanApplicationResponse
{
    public Guid Id { get; set; }
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public Guid DestinationAccountId { get; set; }
    public string DestinationAccountNumber { get; set; } = string.Empty;
    public decimal Principal { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal EstimatedMonthlyPayment { get; set; }
    public decimal EstimatedTotalInterest { get; set; }
    public decimal EstimatedTotalRepayment { get; set; }
    public LoanApplicationStatus Status { get; set; }
    public DateTime SubmittedAtUtc { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
    public string? AdminNote { get; set; }
}
