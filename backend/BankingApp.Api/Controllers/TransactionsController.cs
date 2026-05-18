using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
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

        [HttpPut("{id:guid}")]
        public async Task<ActionResult<TransactionResponse>> Update(
            Guid id,
            TransactionUpdateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await transactionService.UpdateAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
        {
            await transactionService.DeleteAsync(id, cancellationToken);
            return NoContent();
        }
    }
}
