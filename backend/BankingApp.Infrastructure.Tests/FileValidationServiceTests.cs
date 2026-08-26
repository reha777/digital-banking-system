using BankingApp.Application.Common.Exceptions;
using BankingApp.Infrastructure.Services;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public sealed class FileValidationServiceTests
{
    private readonly FileValidationService service = new();
    public static byte[] Pdf => "%PDF-1.7\ncontent"u8.ToArray();
    public static byte[] Jpeg => [0xFF, 0xD8, 0xFF, 0xE0, 1, 2];
    public static byte[] Png => [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1];

    [Theory]
    [MemberData(nameof(ValidDocuments))]
    public void Valid_documents_are_accepted(string name, string mime, byte[] content) => Assert.Equal(mime, service.ValidateDocument(name, mime, content).ContentType);
    public static TheoryData<string, string, byte[]> ValidDocuments => new() { { "proof.pdf", "application/pdf", Pdf }, { "photo.jpg", "image/jpeg", Jpeg }, { "photo.png", "image/png", Png }, { "note.txt", "text/plain", "valid utf8"u8.ToArray() } };

    [Theory]
    [InlineData("evil.jpg", "image/jpeg")]
    [InlineData("fake.pdf", "application/pdf")]
    public void Fake_signatures_are_rejected(string name, string mime) => Assert.Throws<BusinessException>(() => service.ValidateDocument(name, mime, [1, 2, 3, 4, 5, 6, 7, 8]));

    [Fact] public void Spoofed_mime_is_rejected() => Assert.Throws<BusinessException>(() => service.ValidateDocument("photo.png", "image/png", Pdf));
    [Fact] public void Unsupported_extension_is_rejected() => Assert.Throws<BusinessException>(() => service.ValidateDocument("evil.exe", "application/octet-stream", Pdf));
    [Fact] public void Oversized_document_is_rejected() => Assert.Throws<BusinessException>(() => service.ValidateDocument("large.pdf", "application/pdf", new byte[5 * 1024 * 1024 + 1]));
    [Theory, InlineData("../proof.pdf"), InlineData("folder/proof.pdf"), InlineData("C:\\proof.pdf")]
    public void Path_like_names_are_rejected(string name) => Assert.Throws<BusinessException>(() => service.ValidateDocument(name, "application/pdf", Pdf));
    [Fact] public void Binary_txt_is_rejected() => Assert.Throws<BusinessException>(() => service.ValidateDocument("note.txt", "text/plain", [1, 0, 2]));
    [Fact] public void Profile_image_uses_same_magic_validation() => Assert.Equal("image/png", service.ValidateProfileImage("image/png", Png));
}
