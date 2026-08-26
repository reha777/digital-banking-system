using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Loans;

public class AdminLoanApplicationQueryRequest : PagedRequest
{
    public Guid? CustomerId { get; set; }
    public string? Search { get; set; }
    public LoanApplicationStatus? Status { get; set; }
    public DateTime? DateFromUtc { get; set; }
    public DateTime? DateToUtc { get; set; }
}

public class AdminLoanApplicationListItemResponse
{
    public Guid ApplicationId { get; set; }
    public Guid CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public decimal Principal { get; set; }
    public string Currency { get; set; } = string.Empty;
    public int TermMonths { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public decimal EstimatedMonthlyPayment { get; set; }
    public LoanApplicationStatus Status { get; set; }
    public DateTime SubmittedAtUtc { get; set; }
}

public class AdminLoanApplicationDetailsResponse
{
    public Guid Id { get; set; }
    public LoanApplicationStatus Status { get; set; }
    public DateTime SubmittedAtUtc { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
    public string? AdminNote { get; set; }
    public Guid? LoanPurposeId { get; set; }
    public string? LoanPurposeName { get; set; }
    public AdminLoanCustomerResponse Customer { get; set; } = new();
    public AdminLoanProductResponse Product { get; set; } = new();
    public AdminLoanDestinationAccountResponse DestinationAccount { get; set; } = new();
    public AdminLoanFinancialsResponse Financials { get; set; } = new();
}

public class AdminLoanCustomerResponse
{
    public Guid Id { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public CustomerStatus Status { get; set; }
}

public class AdminLoanProductResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
}

public class AdminLoanDestinationAccountResponse
{
    public Guid AccountId { get; set; }
    public string MaskedAccountNumber { get; set; } = string.Empty;
    public AccountType AccountType { get; set; }
    public string Currency { get; set; } = string.Empty;
    public decimal CurrentBalance { get; set; }
}

public class AdminLoanFinancialsResponse
{
    public decimal Principal { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal EstimatedMonthlyPayment { get; set; }
    public decimal EstimatedTotalInterest { get; set; }
    public decimal EstimatedTotalRepayment { get; set; }
}

public class AdminLoanSummaryResponse
{
    public int TotalApplications { get; set; }
    public int PendingApplications { get; set; }
    public int ApprovedApplications { get; set; }
    public int RejectedApplications { get; set; }
}

public class AdminLoanReviewRequest
{
    public string? AdminNote { get; set; }
}

public class AdminLoanQueryRequest : PagedRequest
{
    public Guid? CustomerId { get; set; }
    public LoanStatus? Status { get; set; }
    public string? Search { get; set; }
    public DateTime? DateFromUtc { get; set; }
    public DateTime? DateToUtc { get; set; }
    public bool? OverdueOnly { get; set; }
}

public class AdminLoanListItemResponse
{
    public Guid LoanId { get; set; }
    public Guid ApplicationId { get; set; }
    public Guid CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public decimal OriginalPrincipal { get; set; }
    public decimal OutstandingPrincipal { get; set; }
    public decimal MonthlyPayment { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public int TermMonths { get; set; }
    public decimal TotalPaid { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime? NextPaymentDateUtc { get; set; }
    public DateTime MaturityDateUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public LoanStatus Status { get; set; }
    public int PaidInstallments { get; set; }
    public int RemainingInstallments { get; set; }
    public int OverdueInstallmentsCount { get; set; }
    public decimal TotalOverdueAmount { get; set; }
    public DateTime? OldestOverdueDateUtc { get; set; }
}

public class AdminLoanDetailsResponse : AdminLoanListItemResponse
{
    public CustomerStatus CustomerStatus { get; set; }
    public decimal TotalRepayment { get; set; }
    public AdminLoanDestinationAccountResponse DestinationAccount { get; set; } = new();
    public DateTime ApplicationSubmittedAtUtc { get; set; }
    public DateTime? ApplicationReviewedAtUtc { get; set; }
    public LoanApplicationStatus ApplicationStatus { get; set; }
    public decimal ApplicationRequestedPrincipal { get; set; }
    public decimal ApplicationRateSnapshot { get; set; }
    public string? AdminNote { get; set; }
    public IReadOnlyCollection<LoanInstallmentResponse> Installments { get; set; } = [];
    public IReadOnlyCollection<LoanPaymentHistoryResponse> Payments { get; set; } = [];
}

public class AdminLoanCurrencySummaryResponse
{
    public string Currency { get; set; } = string.Empty;
    public decimal OutstandingPrincipal { get; set; }
    public decimal TotalDisbursed { get; set; }
}

public class AdminLoansOverviewResponse
{
    public int TotalApplications { get; set; }
    public int PendingApplications { get; set; }
    public int ActiveLoans { get; set; }
    public int CompletedLoans { get; set; }
    public int LoansWithOverduePayments { get; set; }
    public IReadOnlyCollection<AdminLoanCurrencySummaryResponse> Currencies { get; set; } = [];
}
