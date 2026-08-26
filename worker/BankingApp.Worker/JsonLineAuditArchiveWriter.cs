using System.Text.Json;
using BankingApp.Application.Messaging;
using Microsoft.Extensions.Options;

namespace BankingApp.Worker;

public interface IAuditArchiveWriter
{
    Task<AuditArchiveWriteResult> WriteAsync(
        AuditArchiveRequested message,
        CancellationToken cancellationToken = default);
}

public sealed record AuditArchiveWriteResult(
    Guid JobId,
    string Path,
    int EntryCount,
    bool AlreadyExisted);

public sealed class JsonLineAuditArchiveWriter : IAuditArchiveWriter
{
    private static readonly JsonSerializerOptions SerializerOptions =
        new(JsonSerializerDefaults.Web);
    private readonly string outputDirectory;

    public JsonLineAuditArchiveWriter(IOptions<AuditArchiveOptions> options)
    {
        outputDirectory = Path.GetFullPath(options.Value.OutputDirectory);
    }

    public async Task<AuditArchiveWriteResult> WriteAsync(
        AuditArchiveRequested message,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(outputDirectory);
        var targetPath = Path.Combine(outputDirectory, $"{message.JobId:N}.jsonl");
        if (File.Exists(targetPath))
            return new(message.JobId, targetPath, message.Entries.Count, true);

        var temporaryPath = $"{targetPath}.{Guid.NewGuid():N}.tmp";
        try
        {
            await using (var stream = new FileStream(
                temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                bufferSize: 16 * 1024, useAsync: true))
            await using (var writer = new StreamWriter(stream))
            {
                var header = new
                {
                    recordType = "audit-archive",
                    message.JobId,
                    message.RequestedByUserId,
                    message.RequestedAtUtc,
                    message.DateFromUtc,
                    message.DateToUtc,
                    entryCount = message.Entries.Count
                };
                await writer.WriteLineAsync(
                    JsonSerializer.Serialize(header, SerializerOptions));
                foreach (var entry in message.Entries)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    await writer.WriteLineAsync(
                        JsonSerializer.Serialize(entry, SerializerOptions));
                }
            }

            File.Move(temporaryPath, targetPath, overwrite: false);
            return new(message.JobId, targetPath, message.Entries.Count, false);
        }
        catch (IOException) when (File.Exists(targetPath))
        {
            return new(message.JobId, targetPath, message.Entries.Count, true);
        }
        finally
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
        }
    }
}
