using BankingApp.Application.Auth;

namespace BankingApp.Application.Interfaces
{
    public interface IAuthService
    {
        Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);

        Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);
    }
}
