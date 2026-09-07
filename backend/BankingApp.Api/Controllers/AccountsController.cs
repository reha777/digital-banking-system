using BankingApp.Application.Accounts;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
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

        [HttpPost("{id:guid}/close")]
        [Authorize(Roles = AppRoles.Customer)]
        public async Task<ActionResult<AccountResponse>> Close(
            Guid id,
            CancellationToken cancellationToken)
        {
            return Ok(await accountService.CloseAsync(id, cancellationToken));
        }
    }
}
