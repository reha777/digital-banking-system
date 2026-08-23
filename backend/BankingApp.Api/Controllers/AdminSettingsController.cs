using BankingApp.Application.Interfaces;
using BankingApp.Application.Settings;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Services;
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
    [HttpPost("profile/photo")]
    [RequestSizeLimit(AdminSettingsService.MaximumProfilePhotoSizeBytes + 64 * 1024)]
    public async Task<ActionResult<AdminProfileResponse>> UploadProfilePhoto(
        IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
            return BadRequest(new { message = "Profile photo cannot be empty." });
        if (file.Length > AdminSettingsService.MaximumProfilePhotoSizeBytes)
            return BadRequest(new { message = "Profile photo cannot be larger than 2 MB." });
        var contentType = Path.GetExtension(file.FileName).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            _ => string.Empty
        };
        if (contentType.Length == 0)
            return BadRequest(new { message = "Only JPG and PNG profile photos are allowed." });
        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory, cancellationToken);
        return Ok(await service.UploadProfilePhotoAsync(new AdminProfilePhotoUploadRequest
        {
            Content = memory.ToArray(), ContentType = contentType
        }, cancellationToken));
    }
    [HttpGet("profile/photo")]
    public async Task<IActionResult> GetProfilePhoto(CancellationToken cancellationToken)
    {
        var photo = await service.GetProfilePhotoAsync(cancellationToken);
        return File(photo.Content, photo.ContentType);
    }
    [HttpDelete("profile/photo")]
    public async Task<ActionResult<AdminProfileResponse>> DeleteProfilePhoto(CancellationToken cancellationToken) =>
        Ok(await service.DeleteProfilePhotoAsync(cancellationToken));
    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword(ChangeAdminPasswordRequest request, CancellationToken cancellationToken)
    {
        await service.ChangePasswordAsync(request, cancellationToken);
        return NoContent();
    }
}
