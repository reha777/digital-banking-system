namespace BankingApp.Application.Interfaces;

public sealed record ValidatedFile(string FileName, string ContentType);

public interface IFileValidationService
{
    ValidatedFile ValidateDocument(string fileName, string contentType, byte[] content, int maximumBytes = 5 * 1024 * 1024);
    string ValidateProfileImage(string contentType, byte[] content, int maximumBytes = 2 * 1024 * 1024);
}
