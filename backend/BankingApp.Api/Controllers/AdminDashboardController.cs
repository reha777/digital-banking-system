using BankingApp.Application.Dashboard;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/dashboard")]
public class AdminDashboardController(IAdminDashboardService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<AdminDashboardResponse>> Get(
        [FromQuery] int periodDays = 7,
        CancellationToken cancellationToken = default)
    {
        if (periodDays is not (7 or 30))
            return BadRequest(new { message = "periodDays must be either 7 or 30." });

        return Ok(await service.GetAsync(periodDays, cancellationToken));
    }
}
