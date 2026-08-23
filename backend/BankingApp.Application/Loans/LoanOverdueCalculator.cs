using BankingApp.Domain.Enums;

namespace BankingApp.Application.Loans;

public readonly record struct LoanOverdueState(bool IsOverdue, int DaysOverdue);

public static class LoanOverdueCalculator
{
    public static LoanOverdueState Calculate(
        LoanInstallmentStatus status,
        DateTime dueDateUtc,
        DateTime nowUtc)
    {
        var overdue = status == LoanInstallmentStatus.Pending && dueDateUtc < nowUtc;
        if (!overdue)
            return new LoanOverdueState(false, 0);

        return new LoanOverdueState(
            true,
            Math.Max(0, (nowUtc.Date - dueDateUtc.Date).Days));
    }
}
