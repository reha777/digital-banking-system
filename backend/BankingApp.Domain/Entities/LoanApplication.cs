using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities;

public class LoanApplication
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid LoanProductId { get; set; }
    public Guid DestinationAccountId { get; set; }
    public decimal Principal { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal AnnualInterestRateSnapshot { get; set; }
    public int TermMonths { get; set; }
    public decimal EstimatedMonthlyPayment { get; set; }
    public decimal EstimatedTotalRepayment { get; set; }
    public decimal EstimatedTotalInterest { get; set; }
    public LoanApplicationStatus Status { get; set; }
    public DateTime SubmittedAtUtc { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
    public Guid? ReviewedByUserId { get; set; }
    public string? AdminNote { get; set; }
    public Guid ClientRequestId { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public User User { get; set; } = null!;
    public LoanProduct LoanProduct { get; set; } = null!;
    public Account DestinationAccount { get; set; } = null!;
    public Loan? Loan { get; set; }
}
