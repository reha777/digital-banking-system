using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/[controller]")]
    public class AccountsController(IAccountService accountService) : ControllerBase
    {
        [HttpGet]
        public async Task<ActionResult<PagedResult<AccountResponse>>> Get(
            [FromQuery] AccountQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await accountService.GetAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("balance")]
        public async Task<ActionResult<AccountBalanceSummaryResponse>> GetBalance(
            CancellationToken cancellationToken)
        {
            var response = await accountService.GetBalanceSummaryAsync(cancellationToken);
            return Ok(response);
        }

        [HttpGet("{id:guid}")]
        public async Task<ActionResult<AccountResponse>> GetById(Guid id, CancellationToken cancellationToken)
        {
            var response = await accountService.GetByIdAsync(id, cancellationToken);
            return Ok(response);
        }

        [HttpPost]
        public async Task<ActionResult<AccountResponse>> Create(
            AccountCreateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await accountService.CreateAsync(request, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
        }

        [HttpPut("{id:guid}")]
        public async Task<ActionResult<AccountResponse>> Update(
            Guid id,
            AccountUpdateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await accountService.UpdateAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
        {
            await accountService.DeleteAsync(id, cancellationToken);
            return NoContent();
        }
    }
}
