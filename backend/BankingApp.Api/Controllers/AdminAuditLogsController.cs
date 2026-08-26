using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Messaging;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/audit-logs")]
public sealed class AdminAuditLogsController(
    IAuditLogService service,
    IAuditArchiveRequestService archiveService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AuditLogResponse>>> Get(
        [FromQuery] AuditLogQueryRequest request, CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(request, cancellationToken));

    [HttpPost("archive")]
    public async Task<ActionResult<AuditArchiveJobResponse>> Archive(
        AuditArchiveCreateRequest request,
        CancellationToken cancellationToken) =>
        Accepted(await archiveService.QueueAsync(request, cancellationToken));
}
