using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BankingApp.Infrastructure.Services;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Customer)]
[Route("api/loans")]
public class LoansController(
    ILoanService loanService,
    ILoanRecommendationService recommendationService) : ControllerBase
{
    [HttpGet("recommendations")]
    public async Task<ActionResult<LoanRecommendationResponse>> GetRecommendations(
        CancellationToken cancellationToken) =>
        Ok(await recommendationService.GetRecommendationsAsync(cancellationToken));

    [HttpGet("products")]
    public async Task<ActionResult<PagedResult<LoanProductResponse>>> GetProducts(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await loanService.GetActiveProductsAsync(request, cancellationToken));

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

    [HttpGet("applications/{id:guid}/documents")]
    public async Task<ActionResult<IReadOnlyCollection<LoanDocumentResponse>>> GetDocuments(Guid id, CancellationToken cancellationToken) =>
        Ok(await loanService.GetDocumentsAsync(id, cancellationToken));

    [HttpPost("applications/{id:guid}/documents")]
    [RequestSizeLimit(FileValidationService.MaximumDocumentSizeBytes + 64 * 1024)]
    public async Task<ActionResult<LoanApplicationResponse>> UploadDocument(Guid id, IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0) return BadRequest(new { message = "Document cannot be empty." });
        using var stream = new MemoryStream();
        await file.CopyToAsync(stream, cancellationToken);
        return Ok(await loanService.UploadDocumentAsync(id, new LoanDocumentUploadRequest
        {
            FileName = file.FileName, ContentType = ResolveDocumentContentType(file.FileName, file.ContentType), Content = stream.ToArray()
        }, cancellationToken));
    }

    private static string ResolveDocumentContentType(string fileName, string contentType)
    {
        if (!string.IsNullOrWhiteSpace(contentType) && !contentType.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase))
            return contentType;
        return Path.GetExtension(fileName).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg", ".png" => "image/png", ".pdf" => "application/pdf",
            ".txt" => "text/plain", _ => "application/octet-stream"
        };
    }

    [HttpGet("applications/{applicationId:guid}/documents/{documentId:guid}/download")]
    public async Task<IActionResult> DownloadDocument(Guid applicationId, Guid documentId, CancellationToken cancellationToken)
    {
        var value = await loanService.DownloadDocumentAsync(applicationId, documentId, cancellationToken);
        return File(value.Content, value.ContentType, value.FileName);
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
