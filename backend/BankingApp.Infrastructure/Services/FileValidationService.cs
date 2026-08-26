using System.Text;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;

namespace BankingApp.Infrastructure.Services;

public sealed class FileValidationService : IFileValidationService
{
    public const int MaximumDocumentSizeBytes = 5 * 1024 * 1024;
    public const int MaximumProfileImageSizeBytes = 2 * 1024 * 1024;
    private static readonly IReadOnlyDictionary<string, string> DocumentTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".pdf"] = "application/pdf",
        [".txt"] = "text/plain"
    };

    public ValidatedFile ValidateDocument(string fileName, string contentType, byte[] content, int maximumBytes = MaximumDocumentSizeBytes)
    {
        ValidateSize(content, maximumBytes, "Document");
        var trimmed = fileName.Trim(); var safeName = Path.GetFileName(trimmed);
        if (string.IsNullOrWhiteSpace(safeName) || trimmed.Contains('/') || trimmed.Contains('\\') || trimmed.Any(char.IsControl) || !string.Equals(trimmed, safeName, StringComparison.Ordinal) || Path.IsPathRooted(trimmed)) throw new BusinessException("Document file name is not valid.");
        var extension = Path.GetExtension(safeName);
        if (!DocumentTypes.TryGetValue(extension, out var expectedType)) throw new BusinessException("Only JPG, PNG, PDF and TXT documents are allowed.");
        var normalizedType = contentType.Split(';', 2)[0].Trim().ToLowerInvariant();
        if (!string.Equals(normalizedType, expectedType, StringComparison.OrdinalIgnoreCase) || !MatchesSignature(expectedType, content)) throw new BusinessException("Document content does not match its file type.");
        return new ValidatedFile(safeName, expectedType);
    }

    public string ValidateProfileImage(string contentType, byte[] content, int maximumBytes = MaximumProfileImageSizeBytes)
    {
        ValidateSize(content, maximumBytes, "Profile photo"); var normalized = contentType.Split(';', 2)[0].Trim().ToLowerInvariant();
        if (normalized is not ("image/jpeg" or "image/png") || !MatchesSignature(normalized, content)) throw new BusinessException("Only valid JPG and PNG profile photos are allowed.");
        return normalized;
    }

    private static void ValidateSize(byte[] content, int maximumBytes, string label)
    {
        if (content.Length == 0) throw new BusinessException($"{label} cannot be empty.");
        if (content.Length > maximumBytes) throw new BusinessException($"{label} exceeds the maximum allowed size.");
    }
    private static bool MatchesSignature(string type, byte[] content) => type switch
    {
        "application/pdf" => content.Length >= 4 && content.AsSpan(0, 4).SequenceEqual("%PDF"u8),
        "image/jpeg" => content.Length >= 3 && content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF,
        "image/png" => content.Length >= 8 && content.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
        "text/plain" => IsPlainText(content),
        _ => false
    };
    private static bool IsPlainText(byte[] content)
    {
        if (content.Contains((byte)0)) return false;
        try { _ = new UTF8Encoding(false, true).GetString(content); return true; } catch (DecoderFallbackException) { return false; }
    }
}
