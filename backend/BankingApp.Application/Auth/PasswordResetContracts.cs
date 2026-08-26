using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Auth;

public static class PasswordPolicy { public const int MinimumLength = 6; }
public sealed class ForgotPasswordRequest { [Required, EmailAddress, MaxLength(256)] public string Email { get; set; } = string.Empty; }
public sealed class ForgotPasswordResponse { public string Message { get; init; } = "If an account exists for this email, password reset instructions have been sent."; }
public sealed class DemoForgotPasswordRequest
{
    [Required, EmailAddress, MaxLength(256)] public string Email { get; set; } = string.Empty;
    [Required, RegularExpression("^(customer-primary|customer-secondary|admin)$", ErrorMessage = "Demo account is invalid.")]
    public string DemoAccount { get; set; } = string.Empty;
}
public sealed class ResetPasswordRequest
{
    [Required] public string Token { get; set; } = string.Empty;
    [Required, MinLength(PasswordPolicy.MinimumLength)] public string NewPassword { get; set; } = string.Empty;
    [Required, Compare(nameof(NewPassword))] public string ConfirmPassword { get; set; } = string.Empty;
}
