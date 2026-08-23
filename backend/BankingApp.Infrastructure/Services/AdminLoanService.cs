using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Application.AuditLogs;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace BankingApp.Infrastructure.Services;

public class AdminLoanService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUserService,
    ILoanCalculationService calculationService,
    IAuditLogService? auditLogService = null) : IAdminLoanService
{
    public async Task<PagedResult<AdminLoanApplicationListItemResponse>> GetApplicationsAsync(
        AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken = default)
    {
        var query = ApplyFilters(request, BaseQuery());
        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(value => value.SubmittedAtUtc)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(value => new AdminLoanApplicationListItemResponse
            {
                ApplicationId = value.Id,
                CustomerId = value.UserId,
                CustomerName = (value.User.FirstName + " " + value.User.LastName).Trim(),
                CustomerEmail = value.User.Email,
                ProductName = value.LoanProduct.Name,
                Principal = value.Principal,
                Currency = value.Currency,
                TermMonths = value.TermMonths,
                AnnualInterestRate = value.AnnualInterestRateSnapshot,
                EstimatedMonthlyPayment = value.EstimatedMonthlyPayment,
                Status = value.Status,
                SubmittedAtUtc = value.SubmittedAtUtc
            })
            .ToListAsync(cancellationToken);

        return new PagedResult<AdminLoanApplicationListItemResponse>
        {
            Items = items,
            Page = request.Page,
            PageSize = request.PageSize,
            TotalCount = totalCount
        };
    }

    public async Task<AdminLoanSummaryResponse> GetSummaryAsync(
        AdminLoanApplicationQueryRequest request,
        CancellationToken cancellationToken = default)
    {
        var query = ApplyFilters(request, BaseQuery());
        return new AdminLoanSummaryResponse
        {
            TotalApplications = await query.CountAsync(cancellationToken),
            PendingApplications = await query.CountAsync(value => value.Status == LoanApplicationStatus.Pending, cancellationToken),
            ApprovedApplications = await query.CountAsync(value => value.Status == LoanApplicationStatus.Approved, cancellationToken),
            RejectedApplications = await query.CountAsync(value => value.Status == LoanApplicationStatus.Rejected, cancellationToken)
        };
    }

    public async Task<PagedResult<AdminLoanListItemResponse>> GetLoansAsync(
        AdminLoanQueryRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        if (!request.Status.HasValue)
            throw new BusinessException("Active ili Completed Loan status je obavezan.");
        var nowUtc = DateTime.UtcNow;
        var query = ApplyLoanFilters(request, dbContext.Loans.AsNoTracking(), nowUtc);
        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(value =>
                value.Status == LoanStatus.Completed ? value.CompletedAtUtc : value.StartDateUtc)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(value => new AdminLoanListItemResponse
            {
                LoanId = value.Id,
                ApplicationId = value.LoanApplicationId,
                CustomerId = value.UserId,
                CustomerName = (value.User.FirstName + " " + value.User.LastName).Trim(),
                CustomerEmail = value.User.Email,
                ProductName = value.LoanApplication.LoanProduct.Name,
                Currency = value.Currency,
                OriginalPrincipal = value.OriginalPrincipal,
                OutstandingPrincipal = value.OutstandingPrincipal,
                MonthlyPayment = value.MonthlyPayment,
                AnnualInterestRate = value.AnnualInterestRate,
                TermMonths = value.TermMonths,
                TotalPaid = value.TotalPaid,
                StartDateUtc = value.StartDateUtc,
                NextPaymentDateUtc = value.Status == LoanStatus.Completed ? null : value.NextPaymentDateUtc,
                MaturityDateUtc = value.MaturityDateUtc,
                CompletedAtUtc = value.CompletedAtUtc,
                Status = value.Status,
                PaidInstallments = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Paid),
                RemainingInstallments = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Pending),
                OverdueInstallmentsCount = value.Installments.Count(item =>
                    item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc),
                TotalOverdueAmount = value.Installments
                    .Where(item => item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc)
                    .Sum(item => (decimal?)item.ScheduledAmount) ?? 0m,
                OldestOverdueDateUtc = value.Installments
                    .Where(item => item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc)
                    .Min(item => (DateTime?)item.DueDateUtc)
            }).ToListAsync(cancellationToken);
        if (items.Any(value => value.Status == LoanStatus.Completed && value.RemainingInstallments > 0))
            throw new BusinessException("Completed Loan sadrzi neplacene rate.");
        return new PagedResult<AdminLoanListItemResponse>
        {
            Items = items, Page = request.Page, PageSize = request.PageSize, TotalCount = totalCount
        };
    }

    public async Task<AdminLoanDetailsResponse> GetLoanDetailsAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        var loan = await dbContext.Loans.AsNoTracking().AsSplitQuery()
            .Include(value => value.User)
            .Include(value => value.DestinationAccount)
            .Include(value => value.LoanApplication).ThenInclude(value => value.LoanProduct)
            .Include(value => value.Installments)
            .Include(value => value.Payments).ThenInclude(value => value.LoanInstallment)
            .Include(value => value.Payments).ThenInclude(value => value.SourceAccount)
            .Include(value => value.Payments).ThenInclude(value => value.Transaction)
            .SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
            ?? throw new NotFoundException("Loan nije pronadjen.");
        var response = ToLoanListItem(loan);
        if (response.Status == LoanStatus.Completed && response.RemainingInstallments > 0)
            throw new BusinessException("Completed Loan sadrzi neplacene rate.");
        var nowUtc = DateTime.UtcNow;
        var overdueInstallments = loan.Installments
            .Where(value => LoanOverdueCalculator.Calculate(value.Status, value.DueDateUtc, nowUtc).IsOverdue)
            .ToList();
        return new AdminLoanDetailsResponse
        {
            LoanId = response.LoanId, ApplicationId = response.ApplicationId,
            CustomerId = response.CustomerId, CustomerName = response.CustomerName,
            CustomerEmail = response.CustomerEmail, CustomerStatus = loan.User.Status,
            ProductName = response.ProductName, Currency = response.Currency,
            OriginalPrincipal = response.OriginalPrincipal, OutstandingPrincipal = response.OutstandingPrincipal,
            MonthlyPayment = response.MonthlyPayment, AnnualInterestRate = response.AnnualInterestRate,
            TermMonths = response.TermMonths, TotalPaid = response.TotalPaid, TotalRepayment = loan.TotalRepayment,
            StartDateUtc = response.StartDateUtc, NextPaymentDateUtc = response.NextPaymentDateUtc,
            MaturityDateUtc = response.MaturityDateUtc, CompletedAtUtc = response.CompletedAtUtc,
            Status = response.Status, PaidInstallments = response.PaidInstallments,
            RemainingInstallments = response.RemainingInstallments,
            OverdueInstallmentsCount = overdueInstallments.Count,
            TotalOverdueAmount = overdueInstallments.Sum(value => value.ScheduledAmount),
            OldestOverdueDateUtc = overdueInstallments.OrderBy(value => value.DueDateUtc)
                .Select(value => (DateTime?)value.DueDateUtc).FirstOrDefault(),
            DestinationAccount = new AdminLoanDestinationAccountResponse
            {
                AccountId = loan.DestinationAccountId,
                MaskedAccountNumber = MaskAccount(loan.DestinationAccount.AccountNumber),
                AccountType = loan.DestinationAccount.AccountType,
                Currency = loan.DestinationAccount.Currency,
                CurrentBalance = loan.DestinationAccount.Balance
            },
            ApplicationSubmittedAtUtc = loan.LoanApplication.SubmittedAtUtc,
            ApplicationReviewedAtUtc = loan.LoanApplication.ReviewedAtUtc,
            ApplicationStatus = loan.LoanApplication.Status,
            ApplicationRequestedPrincipal = loan.LoanApplication.Principal,
            ApplicationRateSnapshot = loan.LoanApplication.AnnualInterestRateSnapshot,
            AdminNote = loan.LoanApplication.AdminNote,
            Installments = loan.Installments.OrderBy(value => value.InstallmentNumber).Select(value =>
            {
                var overdue = LoanOverdueCalculator.Calculate(value.Status, value.DueDateUtc, nowUtc);
                return new LoanInstallmentResponse
                {
                Id = value.Id, InstallmentNumber = value.InstallmentNumber, DueDateUtc = value.DueDateUtc,
                ScheduledAmount = value.ScheduledAmount, PrincipalAmount = value.PrincipalAmount,
                InterestAmount = value.InterestAmount, RemainingPrincipalAfter = value.RemainingPrincipalAfter,
                    Status = value.Status, PaidAtUtc = value.PaidAtUtc,
                    IsOverdue = overdue.IsOverdue, DaysOverdue = overdue.DaysOverdue
                };
            }).ToList(),
            Payments = loan.Payments.OrderByDescending(value => value.PaidAtUtc).Select(value => new LoanPaymentHistoryResponse
            {
                PaymentId = value.Id, InstallmentNumber = value.LoanInstallment.InstallmentNumber,
                Amount = value.Amount, PrincipalAmount = value.PrincipalAmount, InterestAmount = value.InterestAmount,
                PaidAtUtc = value.PaidAtUtc, SourceAccountNumber = MaskAccount(value.SourceAccount.AccountNumber),
                TransactionReference = value.Transaction.ReferenceNumber
            }).ToList()
        };
    }

    public async Task<AdminLoansOverviewResponse> GetLoansOverviewAsync(CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        var applications = dbContext.LoanApplications.AsNoTracking();
        var loans = dbContext.Loans.AsNoTracking();
        var nowUtc = DateTime.UtcNow;
        return new AdminLoansOverviewResponse
        {
            TotalApplications = await applications.CountAsync(cancellationToken),
            PendingApplications = await applications.CountAsync(value => value.Status == LoanApplicationStatus.Pending, cancellationToken),
            ActiveLoans = await loans.CountAsync(value => value.Status == LoanStatus.Active, cancellationToken),
            CompletedLoans = await loans.CountAsync(value => value.Status == LoanStatus.Completed, cancellationToken),
            LoansWithOverduePayments = await loans.CountAsync(value =>
                value.Status == LoanStatus.Active && value.Installments.Any(item =>
                    item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc),
                cancellationToken),
            Currencies = await loans.GroupBy(value => value.Currency).Select(group => new AdminLoanCurrencySummaryResponse
            {
                Currency = group.Key,
                OutstandingPrincipal = group.Sum(value => value.OutstandingPrincipal),
                TotalDisbursed = group.Sum(value => value.OriginalPrincipal)
            }).OrderBy(value => value.Currency).ToListAsync(cancellationToken)
        };
    }

    public async Task<AdminLoanApplicationDetailsResponse> GetApplicationDetailsAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        var value = await BaseQuery().SingleOrDefaultAsync(application => application.Id == id, cancellationToken)
            ?? throw new NotFoundException("Loan application nije pronadjen.");
        return ToDetails(value);
    }

    public async Task<AdminLoanApplicationDetailsResponse> RejectApplicationAsync(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        var note = request.AdminNote?.Trim();
        if (string.IsNullOrWhiteSpace(note))
            throw new BusinessException("Razlog odbijanja Loan applicationa je obavezan.");
        var application = await MutableQuery().SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
            ?? throw new NotFoundException("Loan application nije pronadjen.");
        EnsurePending(application);
        application.Status = LoanApplicationStatus.Rejected;
        application.ReviewedAtUtc = DateTime.UtcNow;
        application.ReviewedByUserId = currentUserService.UserId;
        application.AdminNote = note;
        if (auditLogService is not null)
            await auditLogService.RecordAsync(new AuditLogRecordRequest
            {
                Action = AuditLogActions.LoanRejected, EntityType = AuditEntityTypes.LoanApplication,
                EntityId = id.ToString(), Description = "Loan application rejected.", Reason = note
            }, cancellationToken);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            throw new BusinessException("Loan application je u medjuvremenu vec pregledan.");
        }
        return ToDetails(application);
    }

    public async Task<AdminLoanApplicationDetailsResponse> ApproveApplicationAsync(
        Guid id,
        AdminLoanReviewRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureAdmin();
        var strategy = dbContext.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = dbContext.Database.IsRelational()
                ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                : null;
            try
            {
                var application = await MutableQuery().SingleOrDefaultAsync(value => value.Id == id, cancellationToken)
                    ?? throw new NotFoundException("Loan application nije pronadjen.");
                EnsurePending(application);
                ValidateApplication(application);
                if (application.User.Status != CustomerStatus.Active || application.User.IsDeleted)
                    throw new BusinessException("Loan application customer vise nije aktivan.");
                if (application.DestinationAccount.UserId != application.UserId)
                    throw new BusinessException("Destination account ne pripada Loan application customeru.");
                if (!application.DestinationAccount.Currency.Equals(application.Currency, StringComparison.OrdinalIgnoreCase))
                    throw new BusinessException("Destination account valuta ne odgovara Loan application valuti.");
                if (await dbContext.Loans.AnyAsync(value => value.LoanApplicationId == application.Id, cancellationToken))
                    throw new BusinessException("Loan je vec kreiran za ovaj application.");
                if (await dbContext.Loans.AnyAsync(value => value.UserId == application.UserId && value.Status == LoanStatus.Active, cancellationToken))
                    throw new BusinessException("Customer vec ima aktivan Loan.");

                var approvedAtUtc = DateTime.UtcNow;
                var schedule = calculationService.Calculate(
                    application.Principal,
                    application.AnnualInterestRateSnapshot,
                    application.TermMonths,
                    approvedAtUtc);
                ValidateSnapshot(application, schedule);
                var loanId = Guid.NewGuid();
                var transactionId = Guid.NewGuid();
                var disbursement = new Transaction
                {
                    Id = transactionId,
                    AccountId = application.DestinationAccountId,
                    DestinationAccountId = application.DestinationAccountId,
                    ReferenceNumber = $"LOAN-{application.Id:N}",
                    Amount = application.Principal,
                    Type = TransactionType.LoanDisbursement,
                    Description = $"Loan disbursement - {application.LoanProduct.Name}",
                    Status = TransactionStatus.Completed,
                    IsHighRiskReview = false,
                    CreatedAtUtc = approvedAtUtc
                };
                var loan = new Loan
                {
                    Id = loanId,
                    LoanApplicationId = application.Id,
                    UserId = application.UserId,
                    DestinationAccountId = application.DestinationAccountId,
                    OriginalPrincipal = application.Principal,
                    OutstandingPrincipal = application.Principal,
                    Currency = application.Currency,
                    AnnualInterestRate = application.AnnualInterestRateSnapshot,
                    TermMonths = application.TermMonths,
                    MonthlyPayment = application.EstimatedMonthlyPayment,
                    TotalRepayment = application.EstimatedTotalRepayment,
                    TotalPaid = 0m,
                    StartDateUtc = approvedAtUtc,
                    NextPaymentDateUtc = schedule.Schedule.First().DueDate,
                    MaturityDateUtc = schedule.Schedule.Last().DueDate,
                    Status = LoanStatus.Active,
                    CreatedAtUtc = approvedAtUtc,
                    DisbursementTransactionId = transactionId
                };
                var installments = schedule.Schedule.Select(item => new LoanInstallment
                {
                    Id = Guid.NewGuid(),
                    LoanId = loanId,
                    InstallmentNumber = item.InstallmentNumber,
                    DueDateUtc = item.DueDate,
                    ScheduledAmount = item.ScheduledAmount,
                    PrincipalAmount = item.PrincipalAmount,
                    InterestAmount = item.InterestAmount,
                    RemainingPrincipalAfter = item.RemainingPrincipalAfter,
                    Status = LoanInstallmentStatus.Pending
                });

                application.DestinationAccount.Balance += application.Principal;
                dbContext.Transactions.Add(disbursement);
                dbContext.Loans.Add(loan);
                dbContext.LoanInstallments.AddRange(installments);
                application.Status = LoanApplicationStatus.Approved;
                application.ReviewedAtUtc = approvedAtUtc;
                application.ReviewedByUserId = currentUserService.UserId;
                application.AdminNote = string.IsNullOrWhiteSpace(request.AdminNote) ? null : request.AdminNote.Trim();

                if (auditLogService is not null)
                    await auditLogService.RecordAsync(new AuditLogRecordRequest
                    {
                        Action = AuditLogActions.LoanApproved, EntityType = AuditEntityTypes.LoanApplication,
                        EntityId = id.ToString(), Description = "Loan application approved.", Reason = application.AdminNote
                    }, cancellationToken);

                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                    await transaction.CommitAsync(cancellationToken);
                return ToDetails(application);
            }
            catch (DbUpdateException)
            {
                if (transaction is not null)
                    await transaction.RollbackAsync(cancellationToken);
                dbContext.ChangeTracker.Clear();
                throw new BusinessException("Loan application nije moguce odobriti jer je stanje u medjuvremenu promijenjeno.");
            }
            catch
            {
                if (transaction is not null)
                    await transaction.RollbackAsync(cancellationToken);
                dbContext.ChangeTracker.Clear();
                throw;
            }
        });
    }

    private static AdminLoanApplicationDetailsResponse ToDetails(LoanApplication value) => new()
        {
            Id = value.Id,
            Status = value.Status,
            SubmittedAtUtc = value.SubmittedAtUtc,
            ReviewedAtUtc = value.ReviewedAtUtc,
            AdminNote = value.AdminNote,
            Customer = new AdminLoanCustomerResponse
            {
                Id = value.UserId,
                FirstName = value.User.FirstName,
                LastName = value.User.LastName,
                Email = value.User.Email,
                Status = value.User.Status
            },
            Product = new AdminLoanProductResponse
            {
                Id = value.LoanProductId,
                Name = value.LoanProduct.Name,
                Currency = value.LoanProduct.Currency
            },
            DestinationAccount = new AdminLoanDestinationAccountResponse
            {
                AccountId = value.DestinationAccountId,
                MaskedAccountNumber = MaskAccount(value.DestinationAccount.AccountNumber),
                AccountType = value.DestinationAccount.AccountType,
                Currency = value.DestinationAccount.Currency,
                CurrentBalance = value.DestinationAccount.Balance
            },
            Financials = new AdminLoanFinancialsResponse
            {
                Principal = value.Principal,
                AnnualInterestRate = value.AnnualInterestRateSnapshot,
                TermMonths = value.TermMonths,
                EstimatedMonthlyPayment = value.EstimatedMonthlyPayment,
                EstimatedTotalInterest = value.EstimatedTotalInterest,
                EstimatedTotalRepayment = value.EstimatedTotalRepayment
            }
        };

    private IQueryable<LoanApplication> BaseQuery() => dbContext.LoanApplications
        .AsNoTracking()
        .Include(value => value.User)
        .Include(value => value.LoanProduct)
        .Include(value => value.DestinationAccount);

    private IQueryable<LoanApplication> MutableQuery() => dbContext.LoanApplications
        .Include(value => value.User)
        .Include(value => value.LoanProduct)
        .Include(value => value.DestinationAccount);

    private void EnsureAdmin()
    {
        if (!currentUserService.IsAdmin)
            throw new BusinessException("Samo admin moze pregledati Loan application.");
    }

    private static void EnsurePending(LoanApplication application)
    {
        if (application.Status != LoanApplicationStatus.Pending)
            throw new BusinessException("Loan application je vec pregledan.");
    }

    private static void ValidateApplication(LoanApplication value)
    {
        if (value.Principal <= 0 || value.AnnualInterestRateSnapshot < 0 || value.TermMonths <= 0 ||
            value.EstimatedMonthlyPayment <= 0 || value.EstimatedTotalInterest < 0 ||
            value.EstimatedTotalRepayment < value.Principal || string.IsNullOrWhiteSpace(value.Currency))
            throw new BusinessException("Loan application finansijski snapshot nije validan.");
    }

    private static void ValidateSnapshot(LoanApplication application, LoanCalculationResult calculated)
    {
        if (calculated.MonthlyPayment != application.EstimatedMonthlyPayment ||
            calculated.TotalInterest != application.EstimatedTotalInterest ||
            calculated.TotalRepayment != application.EstimatedTotalRepayment)
            throw new BusinessException("Loan application finansijski snapshot nije konzistentan.");
    }

    private static IQueryable<LoanApplication> ApplyFilters(
        AdminLoanApplicationQueryRequest request,
        IQueryable<LoanApplication> query)
    {
        if (request.CustomerId.HasValue)
            query = query.Where(value => value.UserId == request.CustomerId.Value);
        if (request.Status.HasValue)
            query = query.Where(value => value.Status == request.Status.Value);
        if (request.DateFromUtc.HasValue)
            query = query.Where(value => value.SubmittedAtUtc >= request.DateFromUtc.Value);
        if (request.DateToUtc.HasValue)
        {
            var dateTo = request.DateToUtc.Value.Date.AddDays(1);
            query = query.Where(value => value.SubmittedAtUtc < dateTo);
        }
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(value =>
                value.User.FirstName.Contains(search) ||
                value.User.LastName.Contains(search) ||
                value.User.Email.Contains(search) ||
                value.LoanProduct.Name.Contains(search));
        }
        return query;
    }

    private static IQueryable<Loan> ApplyLoanFilters(
        AdminLoanQueryRequest request,
        IQueryable<Loan> query,
        DateTime nowUtc)
    {
        query = query.Where(value => value.Status == request.Status!.Value);
        if (request.CustomerId.HasValue)
            query = query.Where(value => value.UserId == request.CustomerId.Value);
        if (request.OverdueOnly.HasValue)
        {
            if (request.Status != LoanStatus.Active)
                throw new BusinessException("Overdue filter je dostupan samo za Active Loans.");
            query = request.OverdueOnly.Value
                ? query.Where(value => value.Installments.Any(item =>
                    item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc))
                : query.Where(value => !value.Installments.Any(item =>
                    item.Status == LoanInstallmentStatus.Pending && item.DueDateUtc < nowUtc));
        }
        if (request.DateFromUtc.HasValue)
            query = request.Status == LoanStatus.Completed
                ? query.Where(value => value.CompletedAtUtc >= request.DateFromUtc.Value)
                : query.Where(value => value.StartDateUtc >= request.DateFromUtc.Value);
        if (request.DateToUtc.HasValue)
            query = request.Status == LoanStatus.Completed
                ? query.Where(value => value.CompletedAtUtc <= request.DateToUtc.Value)
                : query.Where(value => value.StartDateUtc <= request.DateToUtc.Value);
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(value => value.User.FirstName.Contains(search) ||
                value.User.LastName.Contains(search) || value.User.Email.Contains(search) ||
                value.LoanApplication.LoanProduct.Name.Contains(search));
        }
        return query;
    }

    private static AdminLoanListItemResponse ToLoanListItem(Loan value) => new()
    {
        LoanId = value.Id, ApplicationId = value.LoanApplicationId, CustomerId = value.UserId,
        CustomerName = $"{value.User.FirstName} {value.User.LastName}".Trim(), CustomerEmail = value.User.Email,
        ProductName = value.LoanApplication.LoanProduct.Name, Currency = value.Currency,
        OriginalPrincipal = value.OriginalPrincipal, OutstandingPrincipal = value.OutstandingPrincipal,
        MonthlyPayment = value.MonthlyPayment, AnnualInterestRate = value.AnnualInterestRate,
        TermMonths = value.TermMonths, TotalPaid = value.TotalPaid, StartDateUtc = value.StartDateUtc,
        NextPaymentDateUtc = value.Status == LoanStatus.Completed ? null : value.NextPaymentDateUtc,
        MaturityDateUtc = value.MaturityDateUtc, CompletedAtUtc = value.CompletedAtUtc, Status = value.Status,
        PaidInstallments = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Paid),
        RemainingInstallments = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Pending)
    };

    private static string MaskAccount(string value)
    {
        var digits = new string(value.Where(char.IsDigit).ToArray());
        var ending = digits.Length <= 4 ? digits.PadLeft(4, '0') : digits[^4..];
        return $"**** {ending}";
    }
}
