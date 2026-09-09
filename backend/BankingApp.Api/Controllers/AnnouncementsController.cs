using BankingApp.Application.Announcements;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController, Authorize(Roles = AppRoles.Customer), Route("api/announcements")]
public sealed class AnnouncementsController(IAnnouncementService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AnnouncementResponse>>> Get([FromQuery] AnnouncementQuery query, CancellationToken token) =>
        Ok(await service.GetPublishedAsync(query, token));
}

[ApiController, Authorize(Roles = AppRoles.Admin), Route("api/admin/announcements")]
public sealed class AdminAnnouncementsController(IAnnouncementService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<AnnouncementResponse>>> Get([FromQuery] AnnouncementQuery query, CancellationToken token) => Ok(await service.GetAdminAsync(query, token));
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<AnnouncementResponse>> GetById(Guid id, CancellationToken token) => Ok(await service.GetAdminByIdAsync(id, token));
    [HttpPost]
    public async Task<ActionResult<AnnouncementResponse>> Create(AnnouncementWriteRequest request, CancellationToken token) => Ok(await service.CreateAsync(request, token));
    [HttpPut("{id:guid}")]
    public async Task<ActionResult<AnnouncementResponse>> Update(Guid id, AnnouncementWriteRequest request, CancellationToken token) => Ok(await service.UpdateAsync(id, request, token));
}
