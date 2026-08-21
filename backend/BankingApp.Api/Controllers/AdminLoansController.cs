using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/loans")]
public class AdminLoansController(IAdminLoanService loanService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AdminLoanListItemResponse>>> GetLoans(
        [FromQuery] AdminLoanQueryRequest request, CancellationToken cancellationToken) =>
        Ok(await loanService.GetLoansAsync(request, cancellationToken));

    [HttpGet("summary")]
    public async Task<ActionResult<AdminLoansOverviewResponse>> GetLoansOverview(CancellationToken cancellationToken) =>
        Ok(await loanService.GetLoansOverviewAsync(cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<AdminLoanDetailsResponse>> GetLoanDetails(Guid id, CancellationToken cancellationToken) =>
        Ok(await loanService.GetLoanDetailsAsync(id, cancellationToken));

    [HttpGet("applications")]
    public async Task<ActionResult<PagedResult<AdminLoanApplicationListItemResponse>>> GetApplications(
        [FromQuery] AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.GetApplicationsAsync(request, cancellationToken));

    [HttpGet("applications/summary")]
    public async Task<ActionResult<AdminLoanSummaryResponse>> GetSummary(
        [FromQuery] AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.GetSummaryAsync(request, cancellationToken));

    [HttpGet("applications/{id:guid}")]
    public async Task<ActionResult<AdminLoanApplicationDetailsResponse>> GetApplicationDetails(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await loanService.GetApplicationDetailsAsync(id, cancellationToken));

    [HttpPost("applications/{id:guid}/approve")]
    public async Task<ActionResult<AdminLoanApplicationDetailsResponse>> ApproveApplication(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.ApproveApplicationAsync(id, request, cancellationToken));

    [HttpPost("applications/{id:guid}/reject")]
    public async Task<ActionResult<AdminLoanApplicationDetailsResponse>> RejectApplication(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.RejectApplicationAsync(id, request, cancellationToken));
}
