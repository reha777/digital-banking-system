using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;

namespace BankingApp.Infrastructure.Services;

public class LoanCalculationService : ILoanCalculationService
{
    private const int MoneyDecimals = 2;
    private static readonly MidpointRounding MoneyRounding = MidpointRounding.AwayFromZero;

    public LoanCalculationResult Calculate(
        decimal principal,
        decimal annualInterestRate,
        int termMonths,
        DateTime startDateUtc)
    {
        if (principal <= 0) throw new BusinessException("Glavnica mora biti veca od nule.");
        if (annualInterestRate < 0) throw new BusinessException("Kamatna stopa ne moze biti negativna.");
        if (termMonths <= 0) throw new BusinessException("Period otplate mora biti veci od nule.");

        principal = Money(principal);
        var monthlyRate = annualInterestRate / 12m / 100m;
        var payment = monthlyRate == 0
            ? Money(principal / termMonths)
            : Money(principal * monthlyRate * Power(1m + monthlyRate, termMonths) /
                (Power(1m + monthlyRate, termMonths) - 1m));

        var remaining = principal;
        var schedule = new List<LoanScheduleItemResponse>(termMonths);
        var firstPaymentDate = DateTime.SpecifyKind(startDateUtc.Date, DateTimeKind.Utc).AddMonths(1);

        for (var number = 1; number <= termMonths; number++)
        {
            var interest = Money(remaining * monthlyRate);
            var principalPart = number == termMonths
                ? remaining
                : Money(payment - interest);
            if (principalPart > remaining) principalPart = remaining;
            if (principalPart <= 0) throw new BusinessException("Loan parametri ne daju validan plan otplate.");

            var scheduledAmount = Money(principalPart + interest);
            remaining = number == termMonths ? 0m : Money(remaining - principalPart);
            schedule.Add(new LoanScheduleItemResponse
            {
                InstallmentNumber = number,
                DueDate = firstPaymentDate.AddMonths(number - 1),
                ScheduledAmount = scheduledAmount,
                PrincipalAmount = principalPart,
                InterestAmount = interest,
                RemainingPrincipalAfter = remaining
            });
        }

        var totalRepayment = schedule.Sum(item => item.ScheduledAmount);
        return new LoanCalculationResult
        {
            Principal = principal,
            AnnualInterestRate = annualInterestRate,
            TermMonths = termMonths,
            MonthlyPayment = payment,
            TotalInterest = Money(totalRepayment - principal),
            TotalRepayment = Money(totalRepayment),
            FirstPaymentDate = firstPaymentDate,
            Schedule = schedule
        };
    }

    private static decimal Money(decimal value) =>
        decimal.Round(value, MoneyDecimals, MoneyRounding);

    private static decimal Power(decimal value, int exponent)
    {
        var result = 1m;
        for (var index = 0; index < exponent; index++) result *= value;
        return result;
    }
}
