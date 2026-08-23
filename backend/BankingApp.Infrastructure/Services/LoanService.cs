using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace BankingApp.Infrastructure.Services;

public class LoanService(
    BankingAppDbContext dbContext,
    ICurrentUserService currentUserService,
    ILoanCalculationService calculationService) : ILoanService
{
    public async Task<IReadOnlyCollection<LoanProductResponse>> GetActiveProductsAsync(
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        return await dbContext.LoanProducts
            .AsNoTracking()
            .Where(product => product.IsActive)
            .OrderBy(product => product.Currency)
            .ThenBy(product => product.Name)
            .Select(product => ToResponse(product))
            .ToListAsync(cancellationToken);
    }

    public async Task<LoanQuoteResponse> QuoteAsync(
        LoanQuoteRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var (product, calculation) = await ValidateAndCalculateAsync(
            request.LoanProductId,
            request.Principal,
            request.TermMonths,
            cancellationToken);
        return new LoanQuoteResponse
        {
            ProductId = product.Id,
            ProductName = product.Name,
            Currency = product.Currency,
            Principal = calculation.Principal,
            AnnualInterestRate = calculation.AnnualInterestRate,
            TermMonths = calculation.TermMonths,
            MonthlyPayment = calculation.MonthlyPayment,
            TotalInterest = calculation.TotalInterest,
            TotalRepayment = calculation.TotalRepayment,
            FirstPaymentDate = calculation.FirstPaymentDate,
            Schedule = calculation.Schedule
        };
    }

    public async Task<LoanApplicationResponse> SubmitApplicationAsync(
        LoanApplicationCreateRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        if (request.ClientRequestId == Guid.Empty)
            throw new BusinessException("ClientRequestId je obavezan.");

        var existing = await ApplicationQuery()
            .SingleOrDefaultAsync(value =>
                value.UserId == currentUserService.UserId &&
                value.ClientRequestId == request.ClientRequestId,
                cancellationToken);
        if (existing is not null)
        {
            if (existing.LoanProductId != request.LoanProductId ||
                existing.DestinationAccountId != request.DestinationAccountId ||
                existing.Principal != request.Principal ||
                existing.TermMonths != request.TermMonths)
                throw new BusinessException("ClientRequestId je vec iskoristen za drugaciji Loan zahtjev.");
            return ToApplicationResponse(existing);
        }

        var user = await dbContext.Users.AsNoTracking()
            .SingleOrDefaultAsync(value => value.Id == currentUserService.UserId, cancellationToken)
            ?? throw new NotFoundException("Customer nije pronadjen.");
        if (user.Status != CustomerStatus.Active || user.IsDeleted)
            throw new BusinessException("Samo aktivan customer moze poslati Loan application.");

        var (product, calculation) = await ValidateAndCalculateAsync(
            request.LoanProductId,
            request.Principal,
            request.TermMonths,
            cancellationToken);
        var destination = await dbContext.Accounts.AsNoTracking()
            .SingleOrDefaultAsync(value => value.Id == request.DestinationAccountId, cancellationToken)
            ?? throw new NotFoundException("Destination account nije pronadjen.");
        if (destination.UserId != currentUserService.UserId)
            throw new BusinessException("Destination account ne pripada prijavljenom customeru.");
        if (!destination.Currency.Equals(product.Currency, StringComparison.OrdinalIgnoreCase))
            throw new BusinessException("Destination account valuta mora odgovarati Loan proizvodu.");

        if (await dbContext.LoanApplications.AsNoTracking().AnyAsync(value =>
            value.UserId == currentUserService.UserId &&
            value.Status == LoanApplicationStatus.Pending, cancellationToken))
            throw new BusinessException("Vec postoji Loan application koji ceka pregled.");
        if (await dbContext.Loans.AsNoTracking().AnyAsync(value =>
            value.UserId == currentUserService.UserId &&
            value.Status == LoanStatus.Active, cancellationToken))
            throw new BusinessException("Novi Loan application nije moguc dok postoji aktivan Loan.");

        var application = new LoanApplication
        {
            Id = Guid.NewGuid(),
            UserId = currentUserService.UserId,
            LoanProductId = product.Id,
            DestinationAccountId = destination.Id,
            Principal = calculation.Principal,
            Currency = product.Currency,
            AnnualInterestRateSnapshot = product.AnnualInterestRate,
            TermMonths = calculation.TermMonths,
            EstimatedMonthlyPayment = calculation.MonthlyPayment,
            EstimatedTotalInterest = calculation.TotalInterest,
            EstimatedTotalRepayment = calculation.TotalRepayment,
            Status = LoanApplicationStatus.Pending,
            SubmittedAtUtc = DateTime.UtcNow,
            ClientRequestId = request.ClientRequestId
        };
        dbContext.LoanApplications.Add(application);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            dbContext.ChangeTracker.Clear();
            var retry = await ApplicationQuery().SingleOrDefaultAsync(value =>
                value.UserId == currentUserService.UserId &&
                value.ClientRequestId == request.ClientRequestId,
                cancellationToken);
            if (retry is not null &&
                retry.LoanProductId == request.LoanProductId &&
                retry.DestinationAccountId == request.DestinationAccountId &&
                retry.Principal == request.Principal &&
                retry.TermMonths == request.TermMonths)
                return ToApplicationResponse(retry);
            throw new BusinessException("Loan application nije moguce kreirati jer vec postoji aktivan zahtjev.");
        }
        var created = await ApplicationQuery().SingleAsync(value => value.Id == application.Id, cancellationToken);
        return ToApplicationResponse(created);
    }

    public async Task<LoanApplicationResponse?> GetCurrentApplicationAsync(
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var pending = await ApplicationQuery().FirstOrDefaultAsync(value =>
            value.UserId == currentUserService.UserId &&
            value.Status == LoanApplicationStatus.Pending, cancellationToken);
        var application = pending ?? await ApplicationQuery()
            .Where(value => value.UserId == currentUserService.UserId)
            .OrderByDescending(value => value.ReviewedAtUtc ?? value.SubmittedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        return application is null ? null : ToApplicationResponse(application);
    }

    public async Task<CustomerLoanResponse?> GetCurrentLoanAsync(CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var loan = await LoanQuery().SingleOrDefaultAsync(value =>
            value.UserId == currentUserService.UserId && value.Status == LoanStatus.Active,
            cancellationToken);
        return loan is null ? null : ToLoanResponse(loan);
    }

    public async Task<CustomerLoanResponse?> GetRecentLoanAsync(CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var loan = await LoanQuery()
            .Where(value => value.UserId == currentUserService.UserId)
            .OrderByDescending(value => value.CompletedAtUtc ?? value.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        return loan is null ? null : ToLoanResponse(loan);
    }

    public async Task<LoanDetailsResponse> GetLoanDetailsAsync(
        Guid loanId,
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var loan = await LoanQuery()
            .Include(value => value.Payments).ThenInclude(value => value.LoanInstallment)
            .Include(value => value.Payments).ThenInclude(value => value.SourceAccount)
            .Include(value => value.Payments).ThenInclude(value => value.Transaction)
            .SingleOrDefaultAsync(value =>
                value.Id == loanId && value.UserId == currentUserService.UserId,
            cancellationToken)
            ?? throw new NotFoundException("Loan nije pronadjen.");
        var nowUtc = DateTime.UtcNow;
        return new LoanDetailsResponse
        {
            Loan = ToLoanResponse(loan),
            Installments = loan.Installments.OrderBy(value => value.InstallmentNumber).Select(value =>
            {
                var overdue = LoanOverdueCalculator.Calculate(value.Status, value.DueDateUtc, nowUtc);
                return new LoanInstallmentResponse
                {
                    Id = value.Id,
                    InstallmentNumber = value.InstallmentNumber,
                    DueDateUtc = value.DueDateUtc,
                    ScheduledAmount = value.ScheduledAmount,
                    PrincipalAmount = value.PrincipalAmount,
                    InterestAmount = value.InterestAmount,
                    RemainingPrincipalAfter = value.RemainingPrincipalAfter,
                    Status = value.Status,
                    PaidAtUtc = value.PaidAtUtc,
                    IsOverdue = overdue.IsOverdue,
                    DaysOverdue = overdue.DaysOverdue
                };
            }).ToList(),
            Payments = loan.Payments.OrderByDescending(value => value.PaidAtUtc).Select(value =>
                new LoanPaymentHistoryResponse
                {
                    PaymentId = value.Id,
                    InstallmentNumber = value.LoanInstallment.InstallmentNumber,
                    Amount = value.Amount,
                    PrincipalAmount = value.PrincipalAmount,
                    InterestAmount = value.InterestAmount,
                    PaidAtUtc = value.PaidAtUtc,
                    SourceAccountNumber = MaskAccount(value.SourceAccount.AccountNumber),
                    TransactionReference = value.Transaction.ReferenceNumber
                }).ToList()
        };
    }

    public async Task<LoanPaymentQuoteResponse> GetPaymentQuoteAsync(
        Guid loanId,
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        var loan = await LoanQuery().SingleOrDefaultAsync(value =>
            value.Id == loanId && value.UserId == currentUserService.UserId,
            cancellationToken) ?? throw new NotFoundException("Loan nije pronadjen.");
        if (loan.Status != LoanStatus.Active)
            throw new BusinessException("Samo aktivan Loan moze biti otplacen.");
        var installment = loan.Installments
            .Where(value => value.Status == LoanInstallmentStatus.Pending)
            .OrderBy(value => value.DueDateUtc)
            .FirstOrDefault() ?? throw new BusinessException("Loan nema neplacenih rata.");
        return ToPaymentQuote(loan, installment);
    }

    public async Task<LoanPaymentResultResponse> PayInstallmentAsync(
        Guid loanId,
        LoanPaymentRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureCustomer();
        if (request.SourceAccountId == Guid.Empty)
            throw new BusinessException("Source account je obavezan.");
        if (request.ClientRequestId == Guid.Empty)
            throw new BusinessException("ClientRequestId je obavezan.");

        var strategy = dbContext.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = dbContext.Database.IsRelational()
                ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                : null;
            try
            {
                var existing = await PaymentQuery().SingleOrDefaultAsync(value =>
                    value.LoanId == loanId && value.ClientRequestId == request.ClientRequestId,
                    cancellationToken);
                if (existing is not null)
                {
                    if (existing.Loan.UserId != currentUserService.UserId)
                        throw new NotFoundException("Loan nije pronadjen.");
                    if (existing.SourceAccountId != request.SourceAccountId)
                        throw new BusinessException("ClientRequestId je vec iskoristen sa drugim source accountom.");
                    return ToPaymentResult(existing);
                }

                var loan = await dbContext.Loans
                    .Include(value => value.Installments)
                    .SingleOrDefaultAsync(value =>
                        value.Id == loanId && value.UserId == currentUserService.UserId,
                        cancellationToken) ?? throw new NotFoundException("Loan nije pronadjen.");
                if (loan.Status != LoanStatus.Active)
                    throw new BusinessException("Samo aktivan Loan moze biti otplacen.");
                var installment = loan.Installments
                    .Where(value => value.Status == LoanInstallmentStatus.Pending)
                    .OrderBy(value => value.DueDateUtc)
                    .FirstOrDefault() ?? throw new BusinessException("Loan nema neplacenih rata.");
                if (installment.LoanPaymentId.HasValue ||
                    await dbContext.LoanPayments.AnyAsync(value => value.LoanInstallmentId == installment.Id, cancellationToken))
                    throw new BusinessException("Sljedeca rata je vec placena.");

                var sourceAccount = await dbContext.Accounts.SingleOrDefaultAsync(
                    value => value.Id == request.SourceAccountId,
                    cancellationToken) ?? throw new NotFoundException("Source account nije pronadjen.");
                if (sourceAccount.UserId != currentUserService.UserId)
                    throw new NotFoundException("Source account nije pronadjen.");
                if (!sourceAccount.Currency.Equals(loan.Currency, StringComparison.OrdinalIgnoreCase))
                    throw new BusinessException("Source account valuta mora odgovarati Loan valuti.");
                if (sourceAccount.Balance < installment.ScheduledAmount)
                    throw new BusinessException("Nedovoljno sredstava za placanje rate.");

                var now = DateTime.UtcNow;
                var paymentId = Guid.NewGuid();
                var transactionId = Guid.NewGuid();
                var reference = $"LOAN-PAY-{paymentId:N}";
                var repayment = new Transaction
                {
                    Id = transactionId,
                    AccountId = sourceAccount.Id,
                    SourceAccountId = sourceAccount.Id,
                    ReferenceNumber = reference,
                    Amount = -installment.ScheduledAmount,
                    Type = TransactionType.LoanRepayment,
                    Description = $"Loan installment #{installment.InstallmentNumber} repayment",
                    Status = TransactionStatus.Completed,
                    CreatedAtUtc = now
                };
                var payment = new LoanPayment
                {
                    Id = paymentId,
                    LoanId = loan.Id,
                    LoanInstallmentId = installment.Id,
                    SourceAccountId = sourceAccount.Id,
                    TransactionId = transactionId,
                    Amount = installment.ScheduledAmount,
                    PrincipalAmount = installment.PrincipalAmount,
                    InterestAmount = installment.InterestAmount,
                    PaidAtUtc = now,
                    Status = LoanPaymentStatus.Completed,
                    ClientRequestId = request.ClientRequestId,
                    Loan = loan,
                    LoanInstallment = installment,
                    SourceAccount = sourceAccount,
                    Transaction = repayment
                };

                sourceAccount.Balance -= installment.ScheduledAmount;
                installment.Status = LoanInstallmentStatus.Paid;
                installment.PaidAtUtc = now;
                installment.LoanPaymentId = paymentId;
                installment.Payment = payment;
                loan.OutstandingPrincipal = decimal.Max(0m,
                    decimal.Round(loan.OutstandingPrincipal - installment.PrincipalAmount, 2));
                loan.TotalPaid = decimal.Round(loan.TotalPaid + installment.ScheduledAmount, 2);
                var next = loan.Installments
                    .Where(value => value.Id != installment.Id && value.Status == LoanInstallmentStatus.Pending)
                    .OrderBy(value => value.DueDateUtc)
                    .FirstOrDefault();
                if (next is null)
                {
                    loan.Status = LoanStatus.Completed;
                    loan.OutstandingPrincipal = 0m;
                    loan.TotalPaid = loan.TotalRepayment;
                    loan.CompletedAtUtc = now;
                }
                else
                {
                    loan.NextPaymentDateUtc = next.DueDateUtc;
                }

                dbContext.Transactions.Add(repayment);
                dbContext.LoanPayments.Add(payment);
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                    await transaction.CommitAsync(cancellationToken);
                return ToPaymentResult(payment);
            }
            catch (DbUpdateConcurrencyException)
            {
                if (transaction is not null)
                    await transaction.RollbackAsync(cancellationToken);
                dbContext.ChangeTracker.Clear();
                throw new BusinessException("Rata je u medjuvremenu vec obradjena.");
            }
            catch (DbUpdateException)
            {
                if (transaction is not null)
                    await transaction.RollbackAsync(cancellationToken);
                dbContext.ChangeTracker.Clear();
                var duplicate = await PaymentQuery().SingleOrDefaultAsync(value =>
                    value.LoanId == loanId && value.ClientRequestId == request.ClientRequestId,
                    cancellationToken);
                if (duplicate is not null && duplicate.Loan.UserId == currentUserService.UserId &&
                    duplicate.SourceAccountId == request.SourceAccountId)
                    return ToPaymentResult(duplicate);
                throw new BusinessException("Ratu nije moguce platiti jer je stanje u medjuvremenu promijenjeno.");
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

    private async Task<(LoanProduct Product, LoanCalculationResult Calculation)> ValidateAndCalculateAsync(
        Guid productId,
        decimal principal,
        int termMonths,
        CancellationToken cancellationToken)
    {
        var product = await dbContext.LoanProducts.AsNoTracking()
            .SingleOrDefaultAsync(value => value.Id == productId, cancellationToken)
            ?? throw new NotFoundException("Loan proizvod nije pronadjen.");
        if (!product.IsActive) throw new BusinessException("Loan proizvod trenutno nije aktivan.");
        if (principal != decimal.Round(principal, 2))
            throw new BusinessException("Iznos moze imati najvise dvije decimale.");
        if (principal < product.MinPrincipal || principal > product.MaxPrincipal)
            throw new BusinessException($"Iznos mora biti izmedju {product.MinPrincipal:N2} i {product.MaxPrincipal:N2} {product.Currency}.");
        if (termMonths < product.MinTermMonths || termMonths > product.MaxTermMonths ||
            (termMonths - product.MinTermMonths) % product.TermStepMonths != 0)
            throw new BusinessException("Odabrani period otplate nije podrzan za ovaj proizvod.");
        return (product, calculationService.Calculate(
            principal,
            product.AnnualInterestRate,
            termMonths,
            DateTime.UtcNow));
    }

    private IQueryable<LoanApplication> ApplicationQuery() => dbContext.LoanApplications
        .AsNoTracking()
        .Include(value => value.LoanProduct)
        .Include(value => value.DestinationAccount);

    private IQueryable<Loan> LoanQuery() => dbContext.Loans
        .AsNoTracking()
        .AsSplitQuery()
        .Include(value => value.LoanApplication).ThenInclude(value => value.LoanProduct)
        .Include(value => value.DestinationAccount)
        .Include(value => value.Installments);

    private IQueryable<LoanPayment> PaymentQuery() => dbContext.LoanPayments
        .AsNoTracking()
        .Include(value => value.Loan)
        .Include(value => value.LoanInstallment)
        .Include(value => value.SourceAccount)
        .Include(value => value.Transaction);

    private static CustomerLoanResponse ToLoanResponse(Loan value)
    {
        var nowUtc = DateTime.UtcNow;
        var paid = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Paid);
        var remaining = value.Installments.Count(item => item.Status == LoanInstallmentStatus.Pending);
        if (value.Status == LoanStatus.Completed && remaining > 0)
            throw new BusinessException("Completed Loan sadrzi neplacene rate.");
        var overdue = value.Installments
            .Where(item => LoanOverdueCalculator.Calculate(item.Status, item.DueDateUtc, nowUtc).IsOverdue)
            .ToList();
        return new CustomerLoanResponse
        {
            LoanId = value.Id,
            ApplicationId = value.LoanApplicationId,
            Status = value.Status,
            ProductName = value.LoanApplication.LoanProduct.Name,
            OriginalPrincipal = value.OriginalPrincipal,
            OutstandingPrincipal = value.OutstandingPrincipal,
            Currency = value.Currency,
            AnnualInterestRate = value.AnnualInterestRate,
            TermMonths = value.TermMonths,
            MonthlyPayment = value.MonthlyPayment,
            TotalRepayment = value.TotalRepayment,
            TotalPaid = value.TotalPaid,
            StartDateUtc = value.StartDateUtc,
            NextPaymentDateUtc = value.Status == LoanStatus.Completed ? null : value.NextPaymentDateUtc,
            MaturityDateUtc = value.MaturityDateUtc,
            PaidInstallments = paid,
            RemainingInstallments = remaining,
            OverdueInstallmentsCount = overdue.Count,
            TotalOverdueAmount = overdue.Sum(item => item.ScheduledAmount),
            DestinationAccountId = value.DestinationAccountId,
            DestinationAccountNumber = MaskAccount(value.DestinationAccount.AccountNumber)
        };
    }

    private static LoanPaymentQuoteResponse ToPaymentQuote(Loan loan, LoanInstallment installment)
    {
        var overdue = LoanOverdueCalculator.Calculate(
            installment.Status,
            installment.DueDateUtc,
            DateTime.UtcNow);
        return new LoanPaymentQuoteResponse
        {
        LoanId = loan.Id,
        InstallmentId = installment.Id,
        InstallmentNumber = installment.InstallmentNumber,
        DueDateUtc = installment.DueDateUtc,
        Amount = installment.ScheduledAmount,
        PrincipalAmount = installment.PrincipalAmount,
        InterestAmount = installment.InterestAmount,
        Currency = loan.Currency,
        OutstandingBefore = loan.OutstandingPrincipal,
        OutstandingAfter = decimal.Max(0m, decimal.Round(loan.OutstandingPrincipal - installment.PrincipalAmount, 2)),
            IsFinalInstallment = loan.Installments.Count(value => value.Status == LoanInstallmentStatus.Pending) == 1,
            IsOverdue = overdue.IsOverdue,
            DaysOverdue = overdue.DaysOverdue
        };
    }

    private static LoanPaymentResultResponse ToPaymentResult(LoanPayment value) => new()
    {
        PaymentId = value.Id,
        LoanId = value.LoanId,
        InstallmentNumber = value.LoanInstallment.InstallmentNumber,
        Amount = value.Amount,
        PrincipalAmount = value.PrincipalAmount,
        InterestAmount = value.InterestAmount,
        Currency = value.Loan.Currency,
        OutstandingPrincipal = value.Loan.OutstandingPrincipal,
        NextPaymentDateUtc = value.Loan.Status == LoanStatus.Completed ? null : value.Loan.NextPaymentDateUtc,
        LoanStatus = value.Loan.Status,
        TransactionReference = value.Transaction.ReferenceNumber,
        PaidAtUtc = value.PaidAtUtc
    };

    private static LoanApplicationResponse ToApplicationResponse(LoanApplication value) => new()
    {
        Id = value.Id,
        ProductId = value.LoanProductId,
        ProductName = value.LoanProduct.Name,
        DestinationAccountId = value.DestinationAccountId,
        DestinationAccountNumber = MaskAccount(value.DestinationAccount.AccountNumber),
        Principal = value.Principal,
        Currency = value.Currency,
        AnnualInterestRate = value.AnnualInterestRateSnapshot,
        TermMonths = value.TermMonths,
        EstimatedMonthlyPayment = value.EstimatedMonthlyPayment,
        EstimatedTotalInterest = value.EstimatedTotalInterest,
        EstimatedTotalRepayment = value.EstimatedTotalRepayment,
        Status = value.Status,
        SubmittedAtUtc = value.SubmittedAtUtc,
        ReviewedAtUtc = value.ReviewedAtUtc,
        AdminNote = value.AdminNote
    };

    private static string MaskAccount(string value)
    {
        var digits = new string(value.Where(char.IsDigit).ToArray());
        var ending = digits.Length <= 4 ? digits.PadLeft(4, '0') : digits[^4..];
        return $"**** {ending}";
    }

    private void EnsureCustomer()
    {
        if (currentUserService.IsAdmin)
            throw new BusinessException("Loan proizvodi su dostupni samo customer korisnicima.");
    }

    private static LoanProductResponse ToResponse(LoanProduct product) => new()
    {
        Id = product.Id,
        Name = product.Name,
        Description = product.Description,
        Currency = product.Currency,
        MinPrincipal = product.MinPrincipal,
        MaxPrincipal = product.MaxPrincipal,
        AnnualInterestRate = product.AnnualInterestRate,
        MinTermMonths = product.MinTermMonths,
        MaxTermMonths = product.MaxTermMonths,
        TermStepMonths = product.TermStepMonths
    };
}
