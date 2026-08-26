using BankingApp.Application.Interfaces;
using BankingApp.Application.ReferenceData;
using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Route("api/reference-data")]
public sealed class ReferenceDataController(IReferenceDataService service) : ControllerBase
{
    [Authorize(Roles = AppRoles.Customer)]
    [HttpGet("{type}")]
    public async Task<ActionResult<PagedResult<ReferenceDataResponse>>> GetActive(string type, [FromQuery] ReferenceDataQuery query, CancellationToken token) => Ok(await service.GetAsync(type, query, true, token));
}
