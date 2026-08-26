namespace BankingApp.Application.Loans;

public sealed class LoanRecommendationResponse
{
    public bool CanApply { get; init; }
    public string? BlockReason { get; init; }
    public string Disclaimer { get; init; } =
        "Recommendation is informational and does not represent loan approval.";
    public IReadOnlyCollection<LoanRecommendationItemResponse> Recommendations { get; init; } = [];
}

public sealed class LoanRecommendationItemResponse
{
    public Guid ProductId { get; init; }
    public string ProductName { get; init; } = string.Empty;
    public int Score { get; init; }
    public int Rank { get; init; }
    public IReadOnlyCollection<string> Reasons { get; init; } = [];
    public string Currency { get; init; } = string.Empty;
    public decimal InterestRate { get; init; }
    public decimal MinAmount { get; init; }
    public decimal MaxAmount { get; init; }
    public int MinTermMonths { get; init; }
    public int MaxTermMonths { get; init; }
}
