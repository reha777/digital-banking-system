using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Customers;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers
{
    [ApiController]
    [Authorize(Roles = AppRoles.Admin)]
    [Route("api/admin/customers")]
    public class AdminCustomersController(IAdminCustomerService customerService) : ControllerBase
    {
        [HttpGet]
        public async Task<ActionResult<PagedResult<CustomerResponse>>> Get(
            [FromQuery] CustomerQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await customerService.GetAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpGet("summary")]
        public async Task<ActionResult<CustomerSummaryResponse>> GetSummary(
            [FromQuery] CustomerQueryRequest request,
            CancellationToken cancellationToken)
        {
            var response = await customerService.GetSummaryAsync(request, cancellationToken);
            return Ok(response);
        }

        [HttpPut("{id:guid}")]
        public async Task<ActionResult<CustomerResponse>> Update(
            Guid id,
            CustomerUpdateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await customerService.UpdateAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpPatch("{id:guid}/status")]
        public async Task<ActionResult<CustomerResponse>> UpdateStatus(
            Guid id,
            CustomerStatusUpdateRequest request,
            CancellationToken cancellationToken)
        {
            var response = await customerService.UpdateStatusAsync(id, request, cancellationToken);
            return Ok(response);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
        {
            await customerService.DeleteAsync(id, cancellationToken);
            return NoContent();
        }
    }
}
