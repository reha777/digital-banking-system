using System.Text.Json;
namespace BankingApp.Application.Messaging;
public static class ReportQueues { public const string Generation = "banking.report-generation.v1"; }
public sealed record ReportGenerationRequested(Guid JobId, DateTime RequestedAtUtc);
public static class ReportGenerationMessageSerializer
{
    public static byte[] Serialize(ReportGenerationRequested value) => JsonSerializer.SerializeToUtf8Bytes(value);
    public static ReportGenerationRequested? Deserialize(ReadOnlySpan<byte> value) => JsonSerializer.Deserialize<ReportGenerationRequested>(value);
}
