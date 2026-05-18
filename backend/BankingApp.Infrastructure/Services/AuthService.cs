using BankingApp.Application.Auth;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services
{
    public class AuthService(
        BankingAppDbContext dbContext,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator) : IAuthService
    {
        public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
        {
            var email = request.Email.Trim().ToLowerInvariant();
            var user = await dbContext.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(existingUser => existingUser.Email == email, cancellationToken);

            if (user is null || !passwordHasher.Verify(request.Password, user.PasswordHash))
            {
                throw new BusinessException("Email ili lozinka nisu ispravni.");
            }

            return CreateAuthResponse(user);
        }

        public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
        {
            var email = request.Email.Trim().ToLowerInvariant();
            var emailExists = await dbContext.Users
                .AnyAsync(user => user.Email == email, cancellationToken);

            if (emailExists)
            {
                throw new BusinessException("Korisnik sa ovom email adresom vec postoji.");
            }

            var user = new User
            {
                Id = Guid.NewGuid(),
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                Email = email,
                PhoneNumber = request.PhoneNumber.Trim(),
                PasswordHash = passwordHasher.Hash(request.Password),
                Role = AppRoles.Customer,
                CreatedAtUtc = DateTime.UtcNow
            };

            dbContext.Users.Add(user);
            await dbContext.SaveChangesAsync(cancellationToken);

            return CreateAuthResponse(user);
        }

        private AuthResponse CreateAuthResponse(User user)
        {
            return new AuthResponse
            {
                Token = jwtTokenGenerator.GenerateToken(user),
                User = new UserResponse
                {
                    Id = user.Id,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    Email = user.Email,
                    PhoneNumber = user.PhoneNumber,
                    Role = user.Role
                }
            };
        }
    }
}
