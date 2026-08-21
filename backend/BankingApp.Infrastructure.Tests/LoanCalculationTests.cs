using BankingApp.Application.Common.Exceptions;
using BankingApp.Infrastructure.Services;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class LoanCalculationTests
{
    private readonly LoanCalculationService service = new();
    private static readonly DateTime Start = new(2026, 8, 19, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Standard_fixed_rate_quote_builds_exact_36_month_schedule()
    {
        var result = service.Calculate(10000m, 6.5m, 36, Start);

        Assert.Equal(306.49m, result.MonthlyPayment);
        Assert.Equal(36, result.Schedule.Count);
        Assert.Equal(new DateTime(2026, 9, 19, 0, 0, 0, DateTimeKind.Utc), result.FirstPaymentDate);
        Assert.Equal(10000m, result.Schedule.Sum(item => item.PrincipalAmount));
        Assert.Equal(result.TotalRepayment, result.Schedule.Sum(item => item.ScheduledAmount));
        Assert.Equal(0m, result.Schedule.Last().RemainingPrincipalAfter);
    }

    [Fact]
    public void Zero_interest_uses_equal_division_and_corrects_final_remainder()
    {
        var result = service.Calculate(1000m, 0m, 6, Start);

        Assert.Equal(166.67m, result.MonthlyPayment);
        Assert.Equal(0m, result.TotalInterest);
        Assert.Equal(1000m, result.TotalRepayment);
        Assert.Equal(166.65m, result.Schedule.Last().ScheduledAmount);
        Assert.Equal(0m, result.Schedule.Last().RemainingPrincipalAfter);
    }

    [Theory]
    [InlineData(1000, 6.5, 6)]
    [InlineData(50000, 6.5, 60)]
    [InlineData(500, 5.75, 6)]
    [InlineData(25000, 6.0, 60)]
    public void Supported_boundaries_close_principal_exactly(
        decimal principal,
        decimal rate,
        int term)
    {
        var result = service.Calculate(principal, rate, term, Start);

        Assert.Equal(term, result.Schedule.Count);
        Assert.Equal(principal, result.Schedule.Sum(item => item.PrincipalAmount));
        Assert.Equal(result.TotalRepayment, result.Schedule.Sum(item => item.ScheduledAmount));
        Assert.Equal(0m, result.Schedule.Last().RemainingPrincipalAfter);
    }

    [Theory]
    [InlineData(0, 5, 12)]
    [InlineData(-1, 5, 12)]
    [InlineData(1000, -1, 12)]
    [InlineData(1000, 5, 0)]
    public void Invalid_calculation_inputs_are_rejected(decimal principal, decimal rate, int term)
    {
        Assert.Throws<BusinessException>(() => service.Calculate(principal, rate, term, Start));
    }
}
