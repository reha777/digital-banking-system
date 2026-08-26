using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/[controller]")]
    public class TransactionsController(ITransactionService transactionService) : ControllerBase
    {
        [HttpGet]
        public async Task<ActionResult<PagedResult<TransactionResponse>>> Get(
            [FromQuery] TransactionQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.GetAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("summary")]
        public async Task<ActionResult<TransactionSummaryResponse>> GetSummary(
            [FromQuery] TransactionQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.GetSummaryAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("statistics")]
        public async Task<ActionResult<TransactionStatisticsResponse>> GetStatistics(
            [FromQuery] TransactionStatisticsQuery request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.GetStatisticsAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("{id:guid}")]
        public async Task<ActionResult<TransactionResponse>> GetById(Guid id, CancellationToken cancellationToken)
        {
            var response = await transactionService.GetByIdAsync(id, cancellationToken);
            return Ok(response);
        }

        [HttpPost]
        public async Task<ActionResult<TransactionResponse>> Create(
            TransactionCreateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.CreateAsync(request, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
        }

        [HttpPost("send-money")]
        public async Task<ActionResult<MoneyTransferResponse>> SendMoney(
            MoneyTransferRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.SendMoneyAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("quote")]
        public async Task<ActionResult<MoneyTransferQuoteResponse>> Quote(
            MoneyTransferQuoteRequest request,
            CancellationToken cancellationToken) =>
            Ok(await transactionService.QuoteAsync(request, cancellationToken));

        [HttpPost("internal-transfer/quote")]
        public async Task<ActionResult<MoneyTransferQuoteResponse>> QuoteInternalTransfer(
            InternalTransferQuoteRequest request,
            CancellationToken cancellationToken) =>
            Ok(await transactionService.QuoteInternalTransferAsync(request, cancellationToken));

        [HttpPost("internal-transfer")]
        public async Task<ActionResult<MoneyTransferResponse>> InternalTransfer(
            InternalTransferRequest request,
            CancellationToken cancellationToken) =>
            Ok(await transactionService.InternalTransferAsync(request, cancellationToken));

        [HttpGet("recent-recipients")]
        public async Task<ActionResult<PagedResult<RecentRecipientResponse>>> GetRecentRecipients(
            [FromQuery] PagedRequest request,
            CancellationToken cancellationToken) =>
            Ok(await transactionService.GetRecentRecipientsAsync(request, cancellationToken));

        [HttpGet("recipients/lookup")]
        public async Task<ActionResult<RecentRecipientResponse>> LookupRecipient(
            [FromQuery] string accountNumber,
            CancellationToken cancellationToken) =>
            Ok(await transactionService.LookupRecipientAsync(accountNumber, cancellationToken));

        [HttpPut("{id:guid}")]
        public async Task<ActionResult<TransactionResponse>> Update(
            Guid id,
            TransactionUpdateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.UpdateAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [Authorize(Roles = AppRoles.Admin)]
        [HttpPost("{id:guid}/approve")]
        public async Task<ActionResult<TransactionResponse>> ApproveReview(
            Guid id,
            TransactionReviewRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.ApproveReviewAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [Authorize(Roles = AppRoles.Admin)]
        [HttpPost("{id:guid}/reject")]
        public async Task<ActionResult<TransactionResponse>> RejectReview(
            Guid id,
            TransactionReviewRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.RejectReviewAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [Authorize(Roles = AppRoles.Admin)]
        [HttpPost("{id:guid}/request-documents")]
        public async Task<ActionResult<TransactionResponse>> RequestDocuments(
            Guid id,
            TransactionDocumentsRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.RequestDocumentsAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("{id:guid}/documents")]
        [RequestSizeLimit(FileValidationService.MaximumDocumentSizeBytes + 64 * 1024)]
        public async Task<ActionResult<TransactionResponse>> UploadDocument(
            Guid id,
            IFormFile file,
            [FromForm] Guid? documentTypeId,
            CancellationToken cancellationToken)
        {
            if (file.Length == 0)
            {
                return BadRequest(new { message = "Dokument ne moze biti prazan." });
            }

            await using var stream = file.OpenReadStream();
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream, cancellationToken);

            var response = await transactionService.UploadDocumentAsync(
                id,
                new TransactionDocumentUploadRequest
                {
                    FileName = file.FileName,
                    ContentType = ResolveContentType(file.FileName, file.ContentType),
                    Content = memoryStream.ToArray(),
                    DocumentTypeId = documentTypeId
                },
                cancellationToken);

            return Ok(response);
        }

        [HttpGet("{transactionId:guid}/documents/{documentId:guid}/download")]
        public async Task<IActionResult> DownloadDocument(
            Guid transactionId,
            Guid documentId,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.DownloadDocumentAsync(
                transactionId,
                documentId,
                cancellationToken);

            return File(response.Content, response.ContentType, response.FileName);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
        {
            await transactionService.DeleteAsync(id, cancellationToken);
            return NoContent();
        }

        private static string ResolveContentType(string fileName, string contentType)
        {
            if (!string.IsNullOrWhiteSpace(contentType) &&
                !contentType.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase))
            {
                return contentType;
            }

            return Path.GetExtension(fileName).ToLowerInvariant() switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".pdf" => "application/pdf",
                ".txt" => "text/plain",
                _ => "application/octet-stream"
            };
        }
    }
}
