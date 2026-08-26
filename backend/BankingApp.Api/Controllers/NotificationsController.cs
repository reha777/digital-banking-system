using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController, Authorize, Route("api/notifications")]
public sealed class NotificationsController(INotificationService service) : ControllerBase
{
    [HttpGet] public async Task<IActionResult> Get([FromQuery] NotificationQuery query, CancellationToken token) => Ok(await service.GetAsync(query, token));
    [HttpGet("unread-count")] public async Task<IActionResult> UnreadCount(CancellationToken token) => Ok(new { count = await service.GetUnreadCountAsync(token) });
    [HttpPut("{id:guid}/read")] public async Task<IActionResult> Read(Guid id, CancellationToken token) { await service.MarkReadAsync(id, token); return NoContent(); }
    [HttpPut("read-all")] public async Task<IActionResult> ReadAll(CancellationToken token) { await service.MarkAllReadAsync(token); return NoContent(); }
}
