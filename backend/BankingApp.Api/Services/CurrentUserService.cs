using System.Security.Claims;
using BankingApp.Application.Interfaces;
using BankingApp.Domain.Constants;

namespace BankingApp.Api.Services
{
    public class CurrentUserService(IHttpContextAccessor httpContextAccessor) : ICurrentUserService
    {
        public Guid UserId
        {
            get
            {
                var userId = httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (!Guid.TryParse(userId, out var parsedUserId))
                {
                    throw new UnauthorizedAccessException("Korisnik nije autentificiran.");
                }

                return parsedUserId;
            }
        }

        public bool IsAdmin
        {
            get
            {
                return httpContextAccessor.HttpContext?.User.IsInRole(AppRoles.Admin) == true;
            }
        }
    }
}
