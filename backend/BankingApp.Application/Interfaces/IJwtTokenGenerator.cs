using BankingApp.Domain.Entities;

namespace BankingApp.Application.Interfaces
{
    public interface IJwtTokenGenerator
    {
        string GenerateToken(User user);
    }
}
