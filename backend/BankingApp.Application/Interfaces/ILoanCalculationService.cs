using BankingApp.Application.Loans;

namespace BankingApp.Application.Interfaces;

public interface ILoanCalculationService
{
    LoanCalculationResult Calculate(
        decimal principal,
        decimal annualInterestRate,
        int termMonths,
        DateTime startDateUtc);
}
