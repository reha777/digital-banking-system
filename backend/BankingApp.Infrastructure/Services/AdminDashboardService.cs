using BankingApp.Application.Common.Models;
using BankingApp.Application.Dashboard;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Services;

public class AdminDashboardService(BankingAppDbContext dbContext) : IAdminDashboardService
{
    private const int RecentLimit = 5;

    public async Task<AdminDashboardResponse> GetAsync(
        int periodDays = 7,
        CancellationToken cancellationToken = default)
    {
        if (periodDays is not (7 or 30))
            throw new ArgumentOutOfRangeException(nameof(periodDays), "Dashboard period must be 7 or 30 days.");

        var customerCounts = await dbContext.Users
            .AsNoTracking()
            .Where(user => user.Role == AppRoles.Customer && !user.IsDeleted)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                Total = group.Count(),
                Active = group.Count(user => user.Status == CustomerStatus.Active)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var transactionCounts = await dbContext.Transactions
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(group => new
            {
                Total = group.Count(),
                Completed = group.Count(value => value.Status == TransactionStatus.Completed),
                Failed = group.Count(value => value.Status == TransactionStatus.Failed),
                PendingReviews = group.Count(value => value.IsHighRiskReview && value.Status == TransactionStatus.Pending),
                DocumentsRequested = group.Count(value => value.Status == TransactionStatus.DocumentsRequested)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var transferredByCurrency = await dbContext.Transactions
            .AsNoTracking()
            .Where(value => value.Status == TransactionStatus.Completed)
            .GroupBy(value => value.Account.Currency)
            .Select(group => new CurrencyAmountResponse
            {
                Currency = group.Key,
                Amount = group.Sum(value => value.Amount < 0 ? -value.Amount : value.Amount)
            })
            .OrderBy(value => value.Currency)
            .ToListAsync(cancellationToken);

        var pendingCardRequests = await dbContext.CardRequests
            .AsNoTracking()
            .CountAsync(value => value.Status == CardRequestStatus.Pending ||
                value.Status == CardRequestStatus.DocumentsRequested, cancellationToken);
        var pendingLoanApplications = await dbContext.LoanApplications
            .AsNoTracking()
            .CountAsync(value => value.Status == LoanApplicationStatus.Pending, cancellationToken);
        var activeLoans = await dbContext.Loans
            .AsNoTracking()
            .CountAsync(value => value.Status == LoanStatus.Active, cancellationToken);
        var nowUtc = DateTime.UtcNow;
        var firstDateUtc = nowUtc.Date.AddDays(-(periodDays - 1));
        var activityCounts = await dbContext.Transactions
            .AsNoTracking()
            .Where(value => value.CreatedAtUtc >= firstDateUtc)
            .GroupBy(value => value.CreatedAtUtc.Date)
            .Select(group => new { DateUtc = group.Key, Count = group.Count() })
            .ToDictionaryAsync(value => value.DateUtc, value => value.Count, cancellationToken);
        var transactionActivity = Enumerable.Range(0, periodDays)
            .Select(offset => firstDateUtc.AddDays(offset))
            .Select(date => new TransactionActivityPointResponse
            {
                DateUtc = DateTime.SpecifyKind(date, DateTimeKind.Utc),
                TransactionCount = activityCounts.GetValueOrDefault(date)
            })
            .ToList();
        var overdueLoans = await dbContext.Loans
            .AsNoTracking()
            .CountAsync(value => value.Status == LoanStatus.Active &&
                value.Installments.Any(installment =>
                    installment.Status == LoanInstallmentStatus.Pending &&
                    installment.DueDateUtc < nowUtc), cancellationToken);

        var recentEntities = await dbContext.Transactions
            .AsNoTracking()
            .Include(value => value.Account)
            .ThenInclude(account => account.User)
            .OrderByDescending(value => value.CreatedAtUtc)
            .Take(RecentLimit)
            .ToListAsync(cancellationToken);
        var relatedAccountIds = recentEntities
            .SelectMany(value => new[] { value.SourceAccountId, value.DestinationAccountId })
            .Where(value => value.HasValue)
            .Select(value => value!.Value)
            .Distinct()
            .ToList();
        var relatedAccounts = await dbContext.Accounts
            .AsNoTracking()
            .Include(value => value.User)
            .Where(value => relatedAccountIds.Contains(value.Id))
            .ToDictionaryAsync(value => value.Id, cancellationToken);

        return new AdminDashboardResponse
        {
            PeriodDays = periodDays,
            TransactionActivity = transactionActivity,
            TotalCustomers = customerCounts?.Total ?? 0,
            ActiveCustomers = customerCounts?.Active ?? 0,
            TotalTransactions = transactionCounts?.Total ?? 0,
            CompletedTransactions = transactionCounts?.Completed ?? 0,
            FailedTransactions = transactionCounts?.Failed ?? 0,
            PendingTransactionReviews = transactionCounts?.PendingReviews ?? 0,
            DocumentsRequested = transactionCounts?.DocumentsRequested ?? 0,
            TransferredByCurrency = transferredByCurrency,
            PendingCardRequests = pendingCardRequests,
            PendingLoanApplications = pendingLoanApplications,
            ActiveLoans = activeLoans,
            LoansWithOverduePayments = overdueLoans,
            RecentTransactions = recentEntities.Select(value => ToResponse(value, relatedAccounts)).ToList()
        };
    }

    private static TransactionResponse ToResponse(
        Domain.Entities.Transaction value,
        IReadOnlyDictionary<Guid, Domain.Entities.Account> accounts)
    {
        accounts.TryGetValue(value.SourceAccountId ?? Guid.Empty, out var source);
        accounts.TryGetValue(value.DestinationAccountId ?? Guid.Empty, out var destination);
        return new TransactionResponse
        {
            Id = value.Id,
            AccountId = value.AccountId,
            AccountNumber = value.Account.AccountNumber,
            SourceAccountId = value.SourceAccountId,
            DestinationAccountId = value.DestinationAccountId,
            SourceAccountNumber = source?.AccountNumber,
            DestinationAccountNumber = destination?.AccountNumber,
            SourceCustomerName = CustomerName(source),
            DestinationCustomerName = CustomerName(destination),
            ReferenceNumber = value.ReferenceNumber,
            Amount = value.Amount,
            Currency = value.Account.Currency,
            Type = value.Type,
            Description = value.Description,
            Status = value.Status,
            IsHighRiskReview = value.IsHighRiskReview,
            ReviewReason = value.ReviewReason,
            CreatedAtUtc = value.CreatedAtUtc
        };
    }

    private static string? CustomerName(Domain.Entities.Account? account) => account is null
        ? null
        : $"{account.User.FirstName} {account.User.LastName}".Trim();
}
