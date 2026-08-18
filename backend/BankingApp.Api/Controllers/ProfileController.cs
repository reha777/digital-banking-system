using BankingApp.Application.Interfaces;
using BankingApp.Application.Profiles;
using BankingApp.Domain.Constants;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers;

[ApiController]
[Authorize(Roles = AppRoles.Customer)]
[Route("api/profile")]
public class ProfileController(ICustomerProfileService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CustomerProfileResponse>> Get(CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(cancellationToken));

    [HttpPut]
    public async Task<ActionResult<CustomerProfileResponse>> Update(
        UpdateCustomerProfileRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(request, cancellationToken));

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(
        ChangeCustomerPasswordRequest request,
        CancellationToken cancellationToken)
    {
        await service.ChangePasswordAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("photo")]
    [RequestSizeLimit(CustomerProfileService.MaximumProfilePhotoSizeBytes + 64 * 1024)]
    public async Task<ActionResult<CustomerProfileResponse>> UploadPhoto(
        IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file.Length == 0)
            return BadRequest(new { message = "Profile photo cannot be empty." });
        if (file.Length > CustomerProfileService.MaximumProfilePhotoSizeBytes)
            return BadRequest(new { message = "Profile photo cannot be larger than 2 MB." });

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        var contentType = extension switch
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
        return Ok(await service.UploadPhotoAsync(new CustomerProfilePhotoUploadRequest
        {
            ContentType = contentType,
            Content = memory.ToArray()
        }, cancellationToken));
    }

    [HttpGet("photo")]
    public async Task<IActionResult> GetPhoto(CancellationToken cancellationToken)
    {
        var photo = await service.GetPhotoAsync(cancellationToken);
        return File(photo.Content, photo.ContentType);
    }
}
