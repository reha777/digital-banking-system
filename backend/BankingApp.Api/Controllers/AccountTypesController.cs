using BankingApp.Application.AccountTypes;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController, Authorize, Route("api/account-types")]
public sealed class AccountTypesController(IAccountTypeService service) : ControllerBase
{
    [HttpGet] public async Task<ActionResult<IReadOnlyList<AccountTypeResponse>>> Get(CancellationToken token) => Ok(await service.GetActiveAsync(token));
}
[ApiController, Authorize(Roles = AppRoles.Admin), Route("api/admin/account-types")]
public sealed class AdminAccountTypesController(IAccountTypeService service) : ControllerBase
{
    [HttpGet] public async Task<IActionResult> Get(CancellationToken token) => Ok(await service.GetAdminAsync(token));
    [HttpGet("{id:guid}")] public async Task<IActionResult> Get(Guid id, CancellationToken token) => Ok(await service.GetAdminByIdAsync(id, token));
    [HttpPost] public async Task<IActionResult> Create(AccountTypeCreateRequest request, CancellationToken token) => Ok(await service.CreateAsync(request, token));
    [HttpPut("{id:guid}")] public async Task<IActionResult> Update(Guid id, AccountTypeUpdateRequest request, CancellationToken token) => Ok(await service.UpdateAsync(id, request, token));
    [HttpPost("{id:guid}/activate")] public async Task<IActionResult> Activate(Guid id, CancellationToken token) => Ok(await service.SetActiveAsync(id, true, token));
    [HttpPost("{id:guid}/deactivate")] public async Task<IActionResult> Deactivate(Guid id, CancellationToken token) => Ok(await service.SetActiveAsync(id, false, token));
}
