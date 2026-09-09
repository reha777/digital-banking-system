using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.AccountTypes;

public sealed class AccountTypeCreateRequest
{
    [Required, StringLength(40)] public string Code { get; init; } = string.Empty;
    [Required, StringLength(100)] public string Name { get; init; } = string.Empty;
}
public sealed class AccountTypeUpdateRequest
{
    [Required, StringLength(100)] public string Name { get; init; } = string.Empty;
}
public sealed class AccountTypeResponse
{
    public Guid Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime? UpdatedAtUtc { get; init; }
}
