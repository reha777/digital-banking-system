namespace BankingApp.Application.Transactions;

public sealed class TopUpRequest
{
    public Guid AccountId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public string SourceType { get; set; } = string.Empty;
    public string SourceDescription { get; set; } = string.Empty;
    public Guid ClientRequestId { get; set; }
}
