using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Entities;

public class LoanPayment
{
    public Guid Id { get; set; }
    public Guid LoanId { get; set; }
    public Guid LoanInstallmentId { get; set; }
    public Guid SourceAccountId { get; set; }
    public Guid TransactionId { get; set; }
    public decimal Amount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public DateTime PaidAtUtc { get; set; }
    public LoanPaymentStatus Status { get; set; }
    public Guid ClientRequestId { get; set; }
    public Loan Loan { get; set; } = null!;
    public LoanInstallment LoanInstallment { get; set; } = null!;
    public Account SourceAccount { get; set; } = null!;
    public Transaction Transaction { get; set; } = null!;
}
