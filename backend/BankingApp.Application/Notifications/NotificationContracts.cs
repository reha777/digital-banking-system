using BankingApp.Application.Common.Pagination;
using BankingApp.Domain.Enums;

namespace BankingApp.Application.Notifications;

public static class NotificationEntityTypes { public const string CardRequest = "CardRequest"; public const string Transaction = "Transaction"; public const string LoanApplication = "LoanApplication"; public const string LoanInstallment = "LoanInstallment"; }
public sealed class NotificationQuery : PagedRequest { public bool UnreadOnly { get; set; } }
public sealed class NotificationResponse
{
    public Guid Id { get; init; }
    public string Type { get; init; } = string.Empty; public string Title { get; init; } = string.Empty; public string Message { get; init; } = string.Empty;
    public string? EntityType { get; init; }
    public Guid? EntityId { get; init; }
    public bool IsRead { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime? ReadAtUtc { get; init; }
}
public sealed record NotificationCreate(Guid UserId, NotificationType Type, string Title, string Message, string? EntityType = null, Guid? EntityId = null);
