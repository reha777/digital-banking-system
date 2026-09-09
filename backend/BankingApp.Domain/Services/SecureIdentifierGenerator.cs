using System.Security.Cryptography;

namespace BankingApp.Domain.Services;

/// <summary>
/// Cryptographically strong identifiers for security-relevant values.
/// <see cref="RandomNumberGenerator"/> is used instead of <c>Random</c>/<c>Random.Shared</c>,
/// which is a deterministic PRNG and must never seed card numbers, security
/// codes or account identifiers.
/// </summary>
public static class SecureIdentifierGenerator
{
    /// <summary>
    /// An RFC 4122 version 4 GUID whose entropy comes from the system CSPRNG.
    /// Account numbers are derived from this identifier by
    /// <see cref="AccountNumberGenerator"/>, which stays deterministic.
    /// </summary>
    public static Guid NewGuid()
    {
        var bytes = RandomNumberGenerator.GetBytes(16);
        bytes[7] = (byte)((bytes[7] & 0x0F) | 0x40); // version 4
        bytes[8] = (byte)((bytes[8] & 0x3F) | 0x80); // RFC 4122 variant
        return new Guid(bytes);
    }

    /// <summary>
    /// A digit string of exactly <paramref name="length"/> characters, drawn
    /// without modulo bias via <see cref="RandomNumberGenerator.GetInt32(int, int)"/>.
    /// </summary>
    public static string NewDigits(int length)
    {
        if (length < 1)
            throw new ArgumentOutOfRangeException(nameof(length), "Length must be at least 1.");

        return string.Create(length, length, static (span, count) =>
        {
            for (var index = 0; index < count; index++)
            {
                span[index] = (char)('0' + RandomNumberGenerator.GetInt32(0, 10));
            }
        });
    }
}
