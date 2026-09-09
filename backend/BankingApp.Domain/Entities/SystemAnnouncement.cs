namespace BankingApp.Domain.Entities;

public sealed class SystemAnnouncement
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public DateTime PublishAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid CreatedByAdminId { get; set; }
    public User CreatedByAdmin { get; set; } = null!;
}
