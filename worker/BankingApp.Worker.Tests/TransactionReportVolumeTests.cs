using BankingApp.Application.Messaging;
using BankingApp.Application.Reports;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace BankingApp.Worker.Tests;

/// <summary>
/// Professor item 11: the PDF table lists ledger entries, so a transfer keeps its
/// debit and credit rows, but the volume summary must count the business transfer
/// once.
/// </summary>
public sealed class TransactionReportVolumeTests
{
    [Fact]
    public async Task A_transfer_produces_two_ledger_rows_but_one_business_amount()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddTransferPair("TRX-A", 100m);
        await fixture.SaveAsync();

        var rows = await fixture.BuildRowsAsync();

        // Both ledger entries are still listed for the detail table.
        Assert.Equal(2, rows.Count);
        Assert.All(rows, row => Assert.Equal("TRX-A", row.Reference));
        // Exactly one of them feeds the volume summary.
        Assert.Single(rows, row => row.CountsTowardVolume);
        Assert.Equal(100m, BusinessVolume(rows, "BAM"));
    }

    [Fact]
    public async Task Two_transfers_report_350_not_700()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddTransferPair("TRX-A", 100m);
        fixture.AddTransferPair("TRX-B", 250m);
        await fixture.SaveAsync();

        var rows = await fixture.BuildRowsAsync();

        Assert.Equal(4, rows.Count);
        Assert.Equal(350m, BusinessVolume(rows, "BAM"));
    }

    [Fact]
    public async Task Only_completed_rows_reach_the_volume_summary()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddTransferPair("TRX-DONE", 100m);
        fixture.AddTransferPair("TRX-PENDING", 200m, TransactionStatus.Pending);
        await fixture.SaveAsync();

        Assert.Equal(100m, BusinessVolume(await fixture.BuildRowsAsync(), "BAM"));
    }

    [Fact]
    public async Task Top_up_rows_are_kept_and_counted_once()
    {
        await using var fixture = await Fixture.CreateAsync();
        fixture.AddTopUp("TOPUP-1", 40m);
        fixture.AddTransferPair("TRX-A", 100m);
        await fixture.SaveAsync();

        var rows = await fixture.BuildRowsAsync();

        Assert.Equal(3, rows.Count);
        Assert.Single(rows, row => row.Type == nameof(TransactionType.TopUp));
        Assert.Equal(140m, BusinessVolume(rows, "BAM"));
    }

    [Fact]
    public void The_generated_pdf_still_renders_with_the_volume_flag()
    {
        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;
        var rows = new[]
        {
            new TransactionReportRow(DateTime.UtcNow, "TRX-A", "Ada Bank", "Account •••• 1234", "Transfer", -100, "BAM", "Completed", true),
            new TransactionReportRow(DateTime.UtcNow, "TRX-A", "Bob Bank", "Account •••• 5678", "Transfer", 100, "BAM", "Completed", false)
        };

        var bytes = new QuestPdfReportGenerator().Transactions(rows, DateTime.UtcNow);

        Assert.True(bytes.Length > 1000);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(bytes, 0, 4));
    }

    private static decimal BusinessVolume(IEnumerable<TransactionReportRow> rows, string currency) =>
        rows.Where(row => row.Status == nameof(TransactionStatus.Completed) &&
                          row.CountsTowardVolume && row.Currency == currency)
            .Sum(row => Math.Abs(row.Amount));

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, Account source, Account destination)
        {
            Db = db; Source = source; Destination = destination;
        }

        public BankingAppDbContext Db { get; }
        private Account Source { get; }
        private Account Destination { get; }

        /// <summary>Runs the real handler and captures the rows handed to the PDF generator.</summary>
        public async Task<IReadOnlyList<TransactionReportRow>> BuildRowsAsync()
        {
            var generator = new CapturingGenerator();
            var job = new ReportJob
            {
                Id = Guid.NewGuid(),
                Type = ReportType.TransactionReport,
                Status = ReportJobStatus.Queued,
                FilterJson = "{}",
                RequestedByUserId = Guid.NewGuid(),
                RequestedAtUtc = DateTime.UtcNow
            };
            Db.ReportJobs.Add(job);
            await Db.SaveChangesAsync();

            var options = Options.Create(new ReportGenerationOptions
            {
                MaxRows = 500,
                OutputDirectory = Path.Combine(Path.GetTempPath(), "item11-reports", Guid.NewGuid().ToString("N"))
            });
            var handler = new ReportGenerationHandler(Db, generator, options);
            await handler.HandleAsync(
                ReportGenerationMessageSerializer.Serialize(new ReportGenerationRequested(job.Id, DateTime.UtcNow)),
                CancellationToken.None);

            Directory.Delete(options.Value.OutputDirectory, true);
            return generator.Rows;
        }

        public void AddTransferPair(
            string reference,
            decimal amount,
            TransactionStatus status = TransactionStatus.Completed)
        {
            Db.Transactions.Add(Row(Source, reference, -amount, TransactionType.Transfer, status,
                amount, Source.Id, Destination.Id));
            Db.Transactions.Add(Row(Destination, reference, amount, TransactionType.Transfer, status,
                amount, Source.Id, Destination.Id));
        }

        public void AddTopUp(string reference, decimal amount) =>
            Db.Transactions.Add(Row(Destination, reference, amount, TransactionType.TopUp,
                TransactionStatus.Completed, null, null, Destination.Id));

        private static Transaction Row(
            Account account, string reference, decimal amount, TransactionType type,
            TransactionStatus status, decimal? transferAmount,
            Guid? sourceAccountId, Guid? destinationAccountId) => new()
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                Account = account,
                SourceAccountId = sourceAccountId,
                DestinationAccountId = destinationAccountId,
                ReferenceNumber = reference,
                Amount = amount,
                Type = type,
                TransferAmount = transferAmount,
                TransferCurrency = transferAmount is null ? null : "BAM",
                DestinationAmount = transferAmount,
                Description = "Test",
                Status = status,
                CreatedAtUtc = DateTime.UtcNow
            };

        public Task SaveAsync() => Db.SaveChangesAsync();

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner");
            var recipient = User("Recipient");
            var source = Account(owner, "BA-SOURCE-CHECKING");
            var destination = Account(recipient, "BA-DEST-CHECKING");
            db.Users.AddRange(owner, recipient);
            db.Accounts.AddRange(source, destination);
            await db.SaveChangesAsync();
            return new Fixture(db, source, destination);
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(),
            FirstName = name,
            LastName = "User",
            Email = $"{Guid.NewGuid()}@example.com",
            PhoneNumber = "+38761000000",
            PasswordHash = "hash",
            Role = AppRoles.Customer,
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

    private sealed class CapturingGenerator : IReportPdfGenerator
    {
        public IReadOnlyList<TransactionReportRow> Rows { get; private set; } = [];

        public byte[] Transactions(IReadOnlyList<TransactionReportRow> rows, DateTime generatedAtUtc)
        {
            Rows = rows;
            return [1, 2, 3];
        }

        public byte[] Loans(IReadOnlyList<LoanReportRow> rows, DateTime generatedAtUtc) => [1, 2, 3];
    }
}
