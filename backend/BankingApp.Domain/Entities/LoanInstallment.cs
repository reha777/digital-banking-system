using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities;

public class LoanInstallment
{
    public Guid Id { get; set; }
    public Guid LoanId { get; set; }
    public int InstallmentNumber { get; set; }
    public DateTime DueDateUtc { get; set; }
    public decimal ScheduledAmount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal RemainingPrincipalAfter { get; set; }
    public LoanInstallmentStatus Status { get; set; }
    public DateTime? PaidAtUtc { get; set; }
    public Guid? LoanPaymentId { get; set; }
    public Loan Loan { get; set; } = null!;
    public LoanPayment? Payment { get; set; }
}
