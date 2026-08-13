using BankingApp.Application.Interfaces;
using BankingApp.Application.Settings;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Admin)]
[Route("api/admin/settings")]
public class AdminSettingsController(IAdminSettingsService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<AdminSettingsResponse>> Get(CancellationToken cancellationToken) => Ok(await service.GetAsync(cancellationToken));
    [HttpPut("system")]
    public async Task<ActionResult<SystemSettingsResponse>> UpdateSystem(UpdateSystemSettingsRequest request, CancellationToken cancellationToken) => Ok(await service.UpdateSystemAsync(request, cancellationToken));
    [HttpPut("preferences")]
    public async Task<ActionResult<AdminPreferencesResponse>> UpdatePreferences(UpdateAdminPreferencesRequest request, CancellationToken cancellationToken) => Ok(await service.UpdatePreferencesAsync(request, cancellationToken));
    [HttpPut("profile")]
    public async Task<ActionResult<AdminProfileResponse>> UpdateProfile(UpdateAdminProfileRequest request, CancellationToken cancellationToken) => Ok(await service.UpdateProfileAsync(request, cancellationToken));
    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword(ChangeAdminPasswordRequest request, CancellationToken cancellationToken)
    {
        await service.ChangePasswordAsync(request, cancellationToken);
        return NoContent();
    }
}
