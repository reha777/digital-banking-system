using BankingApp.Application.Interfaces;
using BankingApp.Application.Notifications;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Worker;

public sealed class OverdueNotificationScanner(
    BankingAppDbContext dbContext,
    INotificationWriter notificationWriter,
    TimeProvider timeProvider)
{
    public async Task<int> ScanAsync(CancellationToken cancellationToken = default)
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        var overdue = await dbContext.LoanInstallments
            .AsNoTracking()
            .Where(item =>
                item.Loan.Status == LoanStatus.Active &&
                item.Status == LoanInstallmentStatus.Pending &&
                item.DueDateUtc < now)
            .OrderBy(item => item.DueDateUtc)
            .Take(500)
            .Select(item => new
            {
                item.Id,
                item.InstallmentNumber,
                item.DueDateUtc,
                item.Loan.UserId
            })
            .ToListAsync(cancellationToken);

        foreach (var installment in overdue)
        {
            await notificationWriter.AddAsync(new NotificationCreate(
                installment.UserId,
                NotificationType.LoanPaymentOverdue,
                "Loan payment overdue",
                $"Installment {installment.InstallmentNumber} was due on {installment.DueDateUtc:dd.MM.yyyy}.",
                NotificationEntityTypes.LoanInstallment,
                installment.Id), cancellationToken);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return overdue.Count;
    }
}
