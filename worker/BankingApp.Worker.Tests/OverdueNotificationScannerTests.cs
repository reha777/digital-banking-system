using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Worker.Tests;

public sealed class OverdueNotificationScannerTests
{
    [Fact]
    public async Task Scan_notifies_only_overdue_pending_installment_and_deduplicates_multiple_runs()
    {
        await using var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var customer = new User { Id = Guid.NewGuid(), FirstName = "Loan", LastName = "Customer", Email = "loan@test.local", PhoneNumber = "+38761000000", PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
        var account = new Account { Id = Guid.NewGuid(), UserId = customer.Id, AccountNumber = "1000000001", AccountType = AccountType.Checking, Currency = "BAM", CreatedAtUtc = DateTime.UtcNow };
        var product = new LoanProduct { Id = Guid.NewGuid(), Name = "Personal", Currency = "BAM", MinPrincipal = 100, MaxPrincipal = 10000, AnnualInterestRate = 5, MinTermMonths = 1, MaxTermMonths = 24, TermStepMonths = 1, IsActive = true };
        var application = new LoanApplication { Id = Guid.NewGuid(), UserId = customer.Id, LoanProductId = product.Id, DestinationAccountId = account.Id, Principal = 1000, Currency = "BAM", TermMonths = 3, Status = LoanApplicationStatus.Approved, SubmittedAtUtc = DateTime.UtcNow, ClientRequestId = Guid.NewGuid() };
        var loan = new Loan { Id = Guid.NewGuid(), LoanApplicationId = application.Id, UserId = customer.Id, DestinationAccountId = account.Id, OriginalPrincipal = 1000, OutstandingPrincipal = 1000, Currency = "BAM", TermMonths = 3, Status = LoanStatus.Active, StartDateUtc = DateTime.UtcNow.AddMonths(-2), NextPaymentDateUtc = DateTime.UtcNow.AddDays(-1), MaturityDateUtc = DateTime.UtcNow.AddMonths(2), CreatedAtUtc = DateTime.UtcNow };
        var overdue = Installment(loan.Id, 1, DateTime.UtcNow.AddDays(-1), LoanInstallmentStatus.Pending);
        var future = Installment(loan.Id, 2, DateTime.UtcNow.AddDays(5), LoanInstallmentStatus.Pending);
        var paid = Installment(loan.Id, 3, DateTime.UtcNow.AddDays(-5), LoanInstallmentStatus.Paid);
        db.AddRange(customer, account, product, application, loan, overdue, future, paid);
        await db.SaveChangesAsync();
        var scanner = new OverdueNotificationScanner(db, new NotificationWriter(db), TimeProvider.System);

        await scanner.ScanAsync();
        await scanner.ScanAsync();

        var notification = Assert.Single(await db.Notifications.ToListAsync());
        Assert.Equal(customer.Id, notification.UserId);
        Assert.Equal(overdue.Id, notification.EntityId);
        Assert.Equal(NotificationType.LoanPaymentOverdue, notification.Type);
    }

    private static LoanInstallment Installment(Guid loanId, int number, DateTime due, LoanInstallmentStatus status) => new()
    { Id = Guid.NewGuid(), LoanId = loanId, InstallmentNumber = number, DueDateUtc = due, ScheduledAmount = 100, PrincipalAmount = 90, InterestAmount = 10, Status = status };
}
