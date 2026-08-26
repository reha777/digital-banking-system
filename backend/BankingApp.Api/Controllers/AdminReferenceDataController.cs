using BankingApp.Application.Interfaces;
using BankingApp.Application.ReferenceData;
using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/reference-data/{type}")]
public sealed class AdminReferenceDataController(IReferenceDataService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<ReferenceDataResponse>>> Get(string type, [FromQuery] ReferenceDataQuery query, CancellationToken token) => Ok(await service.GetAsync(type, query, false, token));
    [HttpPost]
    public async Task<ActionResult<ReferenceDataResponse>> Create(string type, ReferenceDataWriteRequest request, CancellationToken token) => Ok(await service.CreateAsync(type, request, token));
    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ReferenceDataResponse>> Update(string type, Guid id, ReferenceDataWriteRequest request, CancellationToken token) => Ok(await service.UpdateAsync(type, id, request, token));
    [HttpPut("{id:guid}/active")]
    public async Task<ActionResult<ReferenceDataResponse>> SetActive(string type, Guid id, [FromBody] bool isActive, CancellationToken token) => Ok(await service.SetActiveAsync(type, id, isActive, token));
}
