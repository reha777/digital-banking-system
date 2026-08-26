using System.Text;
using BankingApp.Application.Messaging;
using BankingApp.Worker;
using Microsoft.Extensions.Options;
using Xunit;

namespace BankingApp.Worker.Tests;

public sealed class AuditArchiveWorkerTests : IDisposable
{
    private readonly string outputDirectory = Path.Combine(
        Path.GetTempPath(), $"banking-audit-worker-tests-{Guid.NewGuid():N}");

    [Fact]
    public void Typed_message_round_trips_through_json_serialization()
    {
        var message = Message();

        var restored = AuditArchiveMessageSerializer.Deserialize(
            AuditArchiveMessageSerializer.Serialize(message));

        Assert.NotNull(restored);
        Assert.Equal(message.JobId, restored.JobId);
        Assert.Equal(message.RequestedByUserId, restored.RequestedByUserId);
        Assert.Single(restored.Entries);
        Assert.Equal("TransactionApproved", restored.Entries[0].Action);
    }

    [Fact]
    public async Task Handler_validates_and_delegates_valid_message_to_business_writer()
    {
        var writer = new CapturingWriter();
        var handler = new AuditArchiveMessageHandler(writer);
        var message = Message();

        var result = await handler.HandleAsync(
            AuditArchiveMessageSerializer.Serialize(message));

        Assert.Equal(message.JobId, writer.Message?.JobId);
        Assert.Equal(message.JobId, result.JobId);
    }

    [Theory]
    [InlineData("not-json")]
    [InlineData("{}")]
    public async Task Handler_rejects_invalid_messages(string body)
    {
        var handler = new AuditArchiveMessageHandler(new CapturingWriter());

        await Assert.ThrowsAsync<InvalidAuditArchiveMessageException>(() =>
            handler.HandleAsync(Encoding.UTF8.GetBytes(body)));
    }

    [Fact]
    public async Task Writer_produces_jsonl_business_artifact_and_is_idempotent()
    {
        var writer = new JsonLineAuditArchiveWriter(
            Options.Create(new AuditArchiveOptions
            {
                OutputDirectory = outputDirectory
            }));
        var message = Message();

        var first = await writer.WriteAsync(message);
        var second = await writer.WriteAsync(message);

        Assert.False(first.AlreadyExisted);
        Assert.True(second.AlreadyExisted);
        Assert.Equal(first.Path, second.Path);
        var lines = await File.ReadAllLinesAsync(first.Path);
        Assert.Equal(2, lines.Length);
        Assert.Contains("audit-archive", lines[0]);
        Assert.Contains("TransactionApproved", lines[1]);
    }

    private static AuditArchiveRequested Message()
    {
        var actorId = Guid.NewGuid();
        return new AuditArchiveRequested(
            Guid.NewGuid(), actorId, DateTime.UtcNow,
            DateTime.UtcNow.AddDays(-1), DateTime.UtcNow,
            [new AuditArchiveEntry(
                Guid.NewGuid(), actorId, "Desktop Admin", "Admin",
                "TransactionApproved", "Transaction", Guid.NewGuid().ToString(),
                "Transaction review approved.", null, null, null, null,
                DateTime.UtcNow)]);
    }

    public void Dispose()
    {
        if (Directory.Exists(outputDirectory))
            Directory.Delete(outputDirectory, recursive: true);
    }

    private sealed class CapturingWriter : IAuditArchiveWriter
    {
        public AuditArchiveRequested? Message { get; private set; }

        public Task<AuditArchiveWriteResult> WriteAsync(
            AuditArchiveRequested message,
            CancellationToken cancellationToken = default)
        {
            Message = message;
            return Task.FromResult(new AuditArchiveWriteResult(
                message.JobId, "capture.jsonl", message.Entries.Count, false));
        }
    }
}
