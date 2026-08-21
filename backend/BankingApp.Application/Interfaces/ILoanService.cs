using BankingApp.Application.Loans;

namespace BankingApp.Application.Interfaces;

public interface ILoanService
{
    Task<IReadOnlyCollection<LoanProductResponse>> GetActiveProductsAsync(
        CancellationToken cancellationToken = default);

    Task<LoanQuoteResponse> QuoteAsync(
        LoanQuoteRequest request,
        CancellationToken cancellationToken = default);

    Task<LoanApplicationResponse> SubmitApplicationAsync(
        LoanApplicationCreateRequest request,
        CancellationToken cancellationToken = default);

    Task<LoanApplicationResponse?> GetCurrentApplicationAsync(
        CancellationToken cancellationToken = default);

    Task<CustomerLoanResponse?> GetCurrentLoanAsync(CancellationToken cancellationToken = default);
    Task<CustomerLoanResponse?> GetRecentLoanAsync(CancellationToken cancellationToken = default);
    Task<LoanDetailsResponse> GetLoanDetailsAsync(Guid loanId, CancellationToken cancellationToken = default);
    Task<LoanPaymentQuoteResponse> GetPaymentQuoteAsync(Guid loanId, CancellationToken cancellationToken = default);
    Task<LoanPaymentResultResponse> PayInstallmentAsync(Guid loanId, LoanPaymentRequest request, CancellationToken cancellationToken = default);
}
