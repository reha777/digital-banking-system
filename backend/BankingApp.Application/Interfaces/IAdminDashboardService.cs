using BankingApp.Application.Dashboard;

namespace BankingApp.Application.Interfaces;

public interface IAdminDashboardService
{
    Task<AdminDashboardResponse> GetAsync(int periodDays = 7, CancellationToken cancellationToken = default);
}
