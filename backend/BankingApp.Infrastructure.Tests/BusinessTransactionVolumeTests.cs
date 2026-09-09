using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Professor item 11: a standard transfer is stored as a debit and a credit ledger
/// row sharing a reference number, so the same business transfer must not be
/// reported as double the volume.
/// </summary>
public sealed class BusinessTransactionVolumeTests
{
    [Fact]
    public async Task A_transfer_of_100_counts_as_100_not_200()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddTransferPair("TRX-A", 100m);
        await f.SaveAsync();

        Assert.Equal(100m, await f.DashboardVolumeAsync("BAM"));
        Assert.Equal(100m, await f.AdminSummaryVolumeAsync("BAM"));
        // Both ledger rows still exist; only the volume is deduplicated.
        Assert.Equal(2, await f.Db.Transactions.CountAsync());
    }

    [Fact]
    public async Task Two_transfers_of_100_and_250_count_as_350_not_700()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddTransferPair("TRX-A", 100m);
        f.AddTransferPair("TRX-B", 250m);
        await f.SaveAsync();

        Assert.Equal(350m, await f.DashboardVolumeAsync("BAM"));
        Assert.Equal(350m, await f.AdminSummaryVolumeAsync("BAM"));
        Assert.Equal(4, await f.Db.Transactions.CountAsync());
    }

    [Fact]
    public async Task Only_completed_transfers_count_towards_volume()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddTransferPair("TRX-DONE", 100m);
        f.AddTransferPair("TRX-PENDING", 200m, TransactionStatus.Pending);
        f.AddTransferPair("TRX-FAILED", 300m, TransactionStatus.Failed);
        await f.SaveAsync();

        Assert.Equal(100m, await f.DashboardVolumeAsync("BAM"));
        Assert.Equal(100m, await f.AdminSummaryVolumeAsync("BAM"));
    }

    [Fact]
    public async Task Internal_transfer_pairs_are_also_counted_once()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddTransferPair("INT-A", 100m, type: TransactionType.InternalTransfer);
        await f.SaveAsync();

        Assert.Equal(100m, await f.DashboardVolumeAsync("BAM"));
    }

    [Fact]
    public async Task Legacy_rows_without_a_reference_stay_separate_business_events()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddSingleRow(reference: string.Empty, amount: 50m);
        f.AddSingleRow(reference: string.Empty, amount: 70m);
        await f.SaveAsync();

        // Never collapsed into one "null reference" group.
        Assert.Equal(120m, await f.DashboardVolumeAsync("BAM"));
    }

    [Fact]
    public async Task Top_up_and_loan_rows_are_counted_exactly_once()
    {
        await using var f = await Fixture.CreateAsync();
        f.AddSingleRow("TOPUP-1", 40m, TransactionType.TopUp);
        f.AddSingleRow("LOAN-1", 500m, TransactionType.LoanDisbursement);
        f.AddSingleRow("LOAN-PAY-1", -60m, TransactionType.LoanRepayment, isSourceRow: true);
        f.AddTransferPair("TRX-A", 100m);
        await f.SaveAsync();

        // Single-row business events keep their amounts and are not grouped with the
        // transfer; the transfer still contributes only 100.
        Assert.Equal(700m, await f.DashboardVolumeAsync("BAM"));
    }

    [Fact]
    public async Task A_cross_currency_transfer_is_attributed_once_to_the_transfer_currency()
    {
        await using var f = await Fixture.CreateAsync();
        // 100 EUR sent from a BAM account to a USD account.
        f.AddTransferPair("TRX-FX", 100m, transferCurrency: "EUR",
            debitAmount: 195.58m, creditAmount: 108.66m, destinationCurrency: "USD");
        await f.SaveAsync();

        Assert.Equal(100m, await f.DashboardVolumeAsync("EUR"));
        // The debit and credit legs are never added together as if one currency.
        Assert.Equal(0m, await f.DashboardVolumeAsync("BAM"));
        Assert.Equal(0m, await f.DashboardVolumeAsync("USD"));
    }

    [Fact]
    public async Task Abnormal_reference_groups_do_not_duplicate_or_crash()
    {
        await using var f = await Fixture.CreateAsync();
        // A credit leg whose debit counterpart is missing. Both legs are written in one
        // SaveChanges, so this is a corrupt state rather than a business event; the rule
        // deliberately errs towards under-counting instead of ever double-counting.
        f.AddRow("ORPHAN", 100m, isCredit: true);
        // Three rows sharing one reference: one debit and two credits.
        f.AddTransferPair("DUPE", 60m);
        f.AddRow("DUPE", 60m, isCredit: true);
        await f.SaveAsync();

        // The orphaned credit adds nothing and the duplicated group still counts 60 once.
        Assert.Equal(60m, await f.DashboardVolumeAsync("BAM"));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User recipient, User admin,
            Account source, Account destination)
        {
            Db = db; Owner = owner; Recipient = recipient; Admin = admin;
            Source = source; Destination = destination;
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User Recipient { get; }
        public User Admin { get; }
        public Account Source { get; }
        public Account Destination { get; }

        public async Task<decimal> DashboardVolumeAsync(string currency)
        {
            var dashboard = await new AdminDashboardService(Db).GetAsync(7);
            return dashboard.TransferredByCurrency
                .Where(value => value.Currency == currency)
                .Sum(value => value.Amount);
        }

        public async Task<decimal> AdminSummaryVolumeAsync(string currency)
        {
            var service = new TransactionService(
                Db, new CurrentUser(Admin.Id, true), new DemoCurrencyConversionService());
            var summary = await service.GetSummaryAsync(new TransactionQueryRequest());
            return summary.TransferredByCurrency
                .Where(value => value.Currency == currency)
                .Sum(value => value.Amount);
        }

        /// <summary>The debit and credit rows a standard transfer really produces.</summary>
        public void AddTransferPair(
            string reference,
            decimal transferAmount,
            TransactionStatus status = TransactionStatus.Completed,
            TransactionType type = TransactionType.Transfer,
            string transferCurrency = "BAM",
            decimal? debitAmount = null,
            decimal? creditAmount = null,
            string? destinationCurrency = null)
        {
            if (destinationCurrency is not null) Destination.Currency = destinationCurrency;
            var debit = debitAmount ?? transferAmount;
            var credit = creditAmount ?? transferAmount;

            Db.Transactions.Add(Row(Source.Id, Source, reference, -debit, type, status,
                transferAmount, transferCurrency, credit, Source.Id, Destination.Id));
            Db.Transactions.Add(Row(Destination.Id, Destination, reference, credit, type, status,
                transferAmount, transferCurrency, credit, Source.Id, Destination.Id));
        }

        /// <summary>A single-row business event (Top Up, loan disbursement, repayment).</summary>
        public void AddSingleRow(
            string reference,
            decimal amount,
            TransactionType type = TransactionType.Transfer,
            bool isSourceRow = false)
        {
            var account = isSourceRow ? Source : Destination;
            Db.Transactions.Add(Row(account.Id, account, reference, amount, type,
                TransactionStatus.Completed, null, null, null,
                isSourceRow ? account.Id : null, isSourceRow ? null : account.Id));
        }

        public void AddRow(string reference, decimal amount, bool isCredit)
        {
            var account = isCredit ? Destination : Source;
            Db.Transactions.Add(Row(account.Id, account, reference, amount,
                TransactionType.Transfer, TransactionStatus.Completed,
                amount, "BAM", amount, Source.Id, Destination.Id));
        }

        private static Transaction Row(
            Guid accountId, Account account, string reference, decimal amount,
            TransactionType type, TransactionStatus status, decimal? transferAmount,
            string? transferCurrency, decimal? destinationAmount,
            Guid? sourceAccountId, Guid? destinationAccountId) => new()
            {
                Id = Guid.NewGuid(),
                AccountId = accountId,
                Account = account,
                SourceAccountId = sourceAccountId,
                DestinationAccountId = destinationAccountId,
                ReferenceNumber = reference,
                Amount = amount,
                Type = type,
                TransferAmount = transferAmount,
                TransferCurrency = transferCurrency,
                DestinationAmount = destinationAmount,
                Description = "Test",
                Status = status,
                CreatedAtUtc = DateTime.UtcNow
            };

        public Task SaveAsync() => Db.SaveChangesAsync();

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            db.SeedAccountTypes();
            var owner = User("Owner", AppRoles.Customer);
            var recipient = User("Recipient", AppRoles.Customer);
            var admin = User("Admin", AppRoles.Admin);
            var source = Account(owner, "BA-SOURCE-CHECKING");
            var destination = Account(recipient, "BA-DEST-CHECKING");
            db.Users.AddRange(owner, recipient, admin);
            db.Accounts.AddRange(source, destination);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, recipient, admin, source, destination);
        }

        private static User User(string name, string role) => new()
        {
            Id = Guid.NewGuid(),
            FirstName = name,
            LastName = "User",
            Email = $"{Guid.NewGuid()}@example.com",
            PhoneNumber = "+38761000000",
            PasswordHash = "hash",
            Role = role,
            Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        private static Account Account(User user, string number) => new()
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            User = user,
            AccountNumber = number,
            AccountTypeId = AccountTypeCodes.CheckingId,
            Currency = "BAM",
            Balance = 1000m,
            Status = AccountStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id, bool admin = false) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => admin;
    }
}
