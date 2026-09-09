using BankingApp.Application.Common.Pagination;
using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Announcements;

public sealed class AnnouncementQuery : PagedRequest
{
    public string? Search { get; set; }
}

public sealed class AnnouncementWriteRequest
{
    [Required, StringLength(160, MinimumLength = 1)]
    public string Title { get; init; } = string.Empty;

    [Required, StringLength(2000, MinimumLength = 1)]
    public string Message { get; init; } = string.Empty;

    public DateTime PublishAtUtc { get; init; }
}

public sealed class AnnouncementResponse
{
    public Guid Id { get; init; }
    public string Title { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
    public DateTime PublishAtUtc { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public Guid CreatedByAdminId { get; init; }
    public bool IsPublished { get; init; }
}
