using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Notifications;

namespace BankingApp.Application.Interfaces;

public interface INotificationWriter
{
    Task AddAsync(NotificationCreate notification, CancellationToken cancellationToken = default);
    Task AddForAdminsAsync(NotificationCreate notification, CancellationToken cancellationToken = default);
}
public interface INotificationService
{
    Task<PagedResult<NotificationResponse>> GetAsync(NotificationQuery query, CancellationToken cancellationToken = default);
    Task<int> GetUnreadCountAsync(CancellationToken cancellationToken = default);
    Task MarkReadAsync(Guid id, CancellationToken cancellationToken = default);
    Task MarkAllReadAsync(CancellationToken cancellationToken = default);
}
