using BankingApp.Domain.Enums;

namespace BankingApp.Application.Loans;

public class CustomerLoanResponse
{
    public Guid LoanId { get; set; }
    public Guid ApplicationId { get; set; }
    public LoanStatus Status { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public decimal OriginalPrincipal { get; set; }
    public decimal OutstandingPrincipal { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal MonthlyPayment { get; set; }
    public decimal TotalRepayment { get; set; }
    public decimal TotalPaid { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime? NextPaymentDateUtc { get; set; }
    public DateTime MaturityDateUtc { get; set; }
    public int PaidInstallments { get; set; }
    public int RemainingInstallments { get; set; }
    public Guid DestinationAccountId { get; set; }
    public string DestinationAccountNumber { get; set; } = string.Empty;
}

public class LoanInstallmentResponse
{
    public Guid Id { get; set; }
    public int InstallmentNumber { get; set; }
    public DateTime DueDateUtc { get; set; }
    public decimal ScheduledAmount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal RemainingPrincipalAfter { get; set; }
    public LoanInstallmentStatus Status { get; set; }
    public DateTime? PaidAtUtc { get; set; }
}

public class LoanPaymentHistoryResponse
{
    public Guid PaymentId { get; set; }
    public int InstallmentNumber { get; set; }
    public decimal Amount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public DateTime PaidAtUtc { get; set; }
    public string SourceAccountNumber { get; set; } = string.Empty;
    public string TransactionReference { get; set; } = string.Empty;
}

public class LoanDetailsResponse
{
    public CustomerLoanResponse Loan { get; set; } = new();
    public IReadOnlyCollection<LoanInstallmentResponse> Installments { get; set; } = [];
    public IReadOnlyCollection<LoanPaymentHistoryResponse> Payments { get; set; } = [];
}

public class LoanPaymentQuoteResponse
{
    public Guid LoanId { get; set; }
    public Guid InstallmentId { get; set; }
    public int InstallmentNumber { get; set; }
    public DateTime DueDateUtc { get; set; }
    public decimal Amount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal OutstandingBefore { get; set; }
    public decimal OutstandingAfter { get; set; }
    public bool IsFinalInstallment { get; set; }
}

public class LoanPaymentRequest
{
    public Guid SourceAccountId { get; set; }
    public Guid ClientRequestId { get; set; }
}

public class LoanPaymentResultResponse
{
    public Guid PaymentId { get; set; }
    public Guid LoanId { get; set; }
    public int InstallmentNumber { get; set; }
    public decimal Amount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal OutstandingPrincipal { get; set; }
    public DateTime? NextPaymentDateUtc { get; set; }
    public LoanStatus LoanStatus { get; set; }
    public string TransactionReference { get; set; } = string.Empty;
    public DateTime PaidAtUtc { get; set; }
}
