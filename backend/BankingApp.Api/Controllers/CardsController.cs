using BankingApp.Application.Cards;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/cards")]
    public class CardsController(ICardService cardService) : ControllerBase
    {
        [HttpGet("my")]
        public async Task<ActionResult<PagedResult<CardResponse>>> GetMyCards(
            [FromQuery] PagedRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.GetMyCardsAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("{id:guid}/sensitive-data")]
        public async Task<ActionResult<CardSensitiveDataResponse>> GetSensitiveData(
            Guid id,
            CancellationToken cancellationToken) =>
            Ok(await cardService.GetSensitiveDataAsync(id, cancellationToken));

        [HttpPost("{id:guid}/freeze")]
        public async Task<ActionResult<CardResponse>> Freeze(
            Guid id,
            CancellationToken cancellationToken) =>
            Ok(await cardService.SetFrozenAsync(id, true, cancellationToken));

        [HttpPost("{id:guid}/unfreeze")]
        public async Task<ActionResult<CardResponse>> Unfreeze(
            Guid id,
            CancellationToken cancellationToken) =>
            Ok(await cardService.SetFrozenAsync(id, false, cancellationToken));

        [HttpGet("requests/my")]
        public async Task<ActionResult<PagedResult<CardRequestResponse>>> GetMyRequests(
            [FromQuery] CardRequestQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.GetMyRequestsAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("requests")]
        public async Task<ActionResult<CardRequestResponse>> CreateRequest(
            CardRequestCreateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.CreateRequestAsync(request, cancellationToken);
            return CreatedAtAction(nameof(GetMyRequests), new { id = response.Id }, response);
        }

        [HttpPost("requests/{id:guid}/documents")]
        [RequestSizeLimit(FileValidationService.MaximumDocumentSizeBytes + 64 * 1024)]
        public async Task<ActionResult<CardRequestResponse>> UploadDocument(
            Guid id,
            IFormFile file,
            CancellationToken cancellationToken)
        {
            if (file.Length == 0)
            {
                return BadRequest(new { message = "Dokument ne moze biti prazan." });
            }

            await using var stream = file.OpenReadStream();
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream, cancellationToken);

            var response = await cardService.UploadDocumentAsync(
                id,
                new CardRequestDocumentUploadRequest
                {
                    FileName = file.FileName,
                    ContentType = ResolveContentType(file.FileName, file.ContentType),
                    Content = memoryStream.ToArray()
                },
                cancellationToken);

            return Ok(response);
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

    [ApiController]
    [Authorize(Roles = AppRoles.Admin)]
    [Route("api/admin/card-requests")]
    public class AdminCardRequestsController(ICardService cardService) : ControllerBase
    {
        [HttpGet]
        public async Task<ActionResult<PagedResult<CardRequestResponse>>> Get(
            [FromQuery] CardRequestQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.GetRequestsAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("summary")]
        public async Task<ActionResult<CardRequestSummaryResponse>> GetSummary(
            [FromQuery] CardRequestQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.GetRequestSummaryAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("{id:guid}/approve")]
        public async Task<ActionResult<CardRequestResponse>> Approve(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.ApproveAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("{id:guid}/reject")]
        public async Task<ActionResult<CardRequestResponse>> Reject(
            Guid id,
            CardRequestReviewRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.RejectAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpPost("{id:guid}/request-documents")]
        public async Task<ActionResult<CardRequestResponse>> RequestDocuments(
            Guid id,
            CardRequestDocumentsRequest request,
            CancellationToken cancellationToken)
        {
            var response = await cardService.RequestDocumentsAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("{requestId:guid}/documents/{documentId:guid}/download")]
        public async Task<IActionResult> DownloadDocument(
            Guid requestId,
            Guid documentId,
            CancellationToken cancellationToken)
        {
            var response = await cardService.DownloadDocumentAsync(
                requestId,
                documentId,
                cancellationToken);

            return File(response.Content, response.ContentType, response.FileName);
        }
    }

    [ApiController]
    [Authorize(Roles = AppRoles.Admin)]
    [Route("api/admin/cards")]
    public class AdminCardsController(ICardService cardService) : ControllerBase
    {
        [HttpGet]
        public async Task<ActionResult<PagedResult<AdminIssuedCardResponse>>> Get(
            [FromQuery] AdminIssuedCardQueryRequest request,
            CancellationToken cancellationToken) =>
            Ok(await cardService.GetIssuedCardsAsync(request, cancellationToken));
    }
}
