using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Customer)]
[Route("api/loans")]
public class LoansController(ILoanService loanService) : ControllerBase
{
    [HttpGet("products")]
    public async Task<ActionResult<IReadOnlyCollection<LoanProductResponse>>> GetProducts(
        CancellationToken cancellationToken) =>
        Ok(await loanService.GetActiveProductsAsync(cancellationToken));

    [HttpPost("quote")]
    public async Task<ActionResult<LoanQuoteResponse>> Quote(
        LoanQuoteRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.QuoteAsync(request, cancellationToken));

    [HttpPost("applications")]
    public async Task<ActionResult<LoanApplicationResponse>> SubmitApplication(
        LoanApplicationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var response = await loanService.SubmitApplicationAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("applications/current")]
    public async Task<ActionResult<LoanApplicationResponse?>> GetCurrentApplication(
        CancellationToken cancellationToken)
    {
        var response = await loanService.GetCurrentApplicationAsync(cancellationToken);
        return response is null ? NoContent() : Ok(response);
    }

    [HttpGet("current")]
    public async Task<ActionResult<CustomerLoanResponse?>> GetCurrentLoan(CancellationToken cancellationToken)
    {
        var response = await loanService.GetCurrentLoanAsync(cancellationToken);
        return response is null ? NoContent() : Ok(response);
    }

    [HttpGet("recent")]
    public async Task<ActionResult<CustomerLoanResponse?>> GetRecentLoan(CancellationToken cancellationToken)
    {
        var response = await loanService.GetRecentLoanAsync(cancellationToken);
        return response is null ? NoContent() : Ok(response);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<LoanDetailsResponse>> GetDetails(Guid id, CancellationToken cancellationToken) =>
        Ok(await loanService.GetLoanDetailsAsync(id, cancellationToken));

    [HttpGet("{id:guid}/payment-quote")]
    public async Task<ActionResult<LoanPaymentQuoteResponse>> GetPaymentQuote(Guid id, CancellationToken cancellationToken) =>
        Ok(await loanService.GetPaymentQuoteAsync(id, cancellationToken));

    [HttpPost("{id:guid}/payments")]
    public async Task<ActionResult<LoanPaymentResultResponse>> PayInstallment(
        Guid id, LoanPaymentRequest request, CancellationToken cancellationToken) =>
        Ok(await loanService.PayInstallmentAsync(id, request, cancellationToken));
}
