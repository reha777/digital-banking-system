using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities;

public class Loan
{
    public Guid Id { get; set; }
    public Guid LoanApplicationId { get; set; }
    public Guid UserId { get; set; }
    public Guid DestinationAccountId { get; set; }
    public decimal OriginalPrincipal { get; set; }
    public decimal OutstandingPrincipal { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal MonthlyPayment { get; set; }
    public decimal TotalRepayment { get; set; }
    public decimal TotalPaid { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime NextPaymentDateUtc { get; set; }
    public DateTime MaturityDateUtc { get; set; }
    public LoanStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public Guid? DisbursementTransactionId { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public LoanApplication LoanApplication { get; set; } = null!;
    public User User { get; set; } = null!;
    public Account DestinationAccount { get; set; } = null!;
    public Transaction? DisbursementTransaction { get; set; }
    public ICollection<LoanInstallment> Installments { get; set; } = new List<LoanInstallment>();
    public ICollection<LoanPayment> Payments { get; set; } = new List<LoanPayment>();
}
