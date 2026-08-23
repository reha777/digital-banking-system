using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/audit-logs")]
public sealed class AdminAuditLogsController(IAuditLogService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AuditLogResponse>>> Get(
        [FromQuery] AuditLogQueryRequest request, CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(request, cancellationToken));
}
