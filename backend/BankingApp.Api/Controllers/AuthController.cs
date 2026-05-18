using BankingApp.Application.Auth;
using BankingApp.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BankingApp.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController(IAuthService authService) : ControllerBase
    {
        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<ActionResult<AuthResponse>> Login(
            LoginRequest request,
            CancellationToken cancellationToken)
        {
            var response = await authService.LoginAsync(request, cancellationToken);
            return Ok(response);
        }

        [AllowAnonymous]
        [HttpPost("register")]
        public async Task<ActionResult<AuthResponse>> Register(
            RegisterRequest request,
            CancellationToken cancellationToken)
        {
            var response = await authService.RegisterAsync(request, cancellationToken);
            return CreatedAtAction(nameof(Register), response);
        }

        [AllowAnonymous]
        [HttpPost("refresh")]
        public async Task<ActionResult<AuthResponse>> Refresh(
            RefreshTokenRequest request,
            CancellationToken cancellationToken)
        {
            var response = await authService.RefreshAsync(request, cancellationToken);
            return Ok(response);
        }

        [AllowAnonymous]
        [HttpPost("logout")]
        public async Task<IActionResult> Logout(
            LogoutRequest request,
            CancellationToken cancellationToken)
        {
            await authService.LogoutAsync(request, cancellationToken);
            return NoContent();
        }
    }
}
