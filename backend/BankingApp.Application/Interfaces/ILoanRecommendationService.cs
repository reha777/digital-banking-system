using BankingApp.Application.Loans;

namespace BankingApp.Application.Interfaces;

public interface ILoanRecommendationService
{
    Task<LoanRecommendationResponse> GetRecommendationsAsync(
        CancellationToken cancellationToken = default);
}
