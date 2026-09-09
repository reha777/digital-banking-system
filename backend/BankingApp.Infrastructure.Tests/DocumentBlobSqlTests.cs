using System.Data.Common;
using System.Text.RegularExpressions;
using BankingApp.Application.Cards;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

/// <summary>
/// Professor item 15, the part that actually matters: proof taken from the SQL the
/// real services emit, not from a hand-written query that merely looks like theirs.
///
/// These run against a relational (SQLite) provider with a command interceptor, so
/// every statement the service executes is captured and inspected.
/// </summary>
public sealed class DocumentBlobSqlTests
{
    [Fact]
    public async Task TransactionService_list_never_selects_the_document_blob()
    {
        await using var f = await SqlFixture.CreateAsync();

        var page = await f.Transactions().GetAsync(new TransactionQueryRequest());

        // The metadata still arrives.
        var document = Assert.Single(Assert.Single(page.Items).Documents);
        Assert.Equal("proof.pdf", document.FileName);
        Assert.Equal(SqlFixture.Content.LongLength, document.SizeBytes);

        f.AssertNoStatementSelectedContent();
    }

    [Fact]
    public async Task TransactionService_detail_never_selects_the_document_blob()
    {
        await using var f = await SqlFixture.CreateAsync();

        var detail = await f.Transactions().GetByIdAsync(f.TransactionId);

        Assert.Equal(
            SqlFixture.Content.LongLength,
            Assert.Single(detail.Documents).SizeBytes);
        f.AssertNoStatementSelectedContent();
    }

    [Fact]
    public async Task CardService_request_list_never_selects_the_document_blob()
    {
        await using var f = await SqlFixture.CreateAsync();

        var page = await f.Cards().GetMyRequestsAsync(new CardRequestQueryRequest());

        var document = Assert.Single(Assert.Single(page.Items).Documents);
        Assert.Equal("card-proof.pdf", document.FileName);
        Assert.Equal(SqlFixture.Content.LongLength, document.SizeBytes);

        f.AssertNoStatementSelectedContent();
    }

    [Fact]
    public async Task The_download_endpoints_do_select_the_blob_and_return_exact_bytes()
    {
        await using var f = await SqlFixture.CreateAsync();

        var transactionDownload = await f.Transactions()
            .DownloadDocumentAsync(f.TransactionId, f.TransactionDocumentId);
        var cardDownload = await f.Cards()
            .DownloadDocumentAsync(f.CardRequestId, f.CardDocumentId);

        Assert.Equal(SqlFixture.Content, transactionDownload.Content);
        Assert.Equal(SqlFixture.Content, cardDownload.Content);
        // Exactly the opposite expectation, proving the detector really fires.
        Assert.Contains(f.Statements, SqlFixture.SelectsContentColumn);
    }

    private sealed class SqlFixture : IAsyncDisposable
    {
        public static readonly byte[] Content = Enumerable.Range(0, 256 * 1024)
            .Select(index => (byte)(index % 251))
            .ToArray();

        private readonly SqliteConnection _connection;
        private readonly CapturingInterceptor _interceptor;

        private SqlFixture(
            SqliteConnection connection,
            BankingAppDbContext db,
            CapturingInterceptor interceptor,
            Guid ownerId,
            Guid transactionId,
            Guid transactionDocumentId,
            Guid cardRequestId,
            Guid cardDocumentId)
        {
            _connection = connection;
            _interceptor = interceptor;
            Db = db;
            OwnerId = ownerId;
            TransactionId = transactionId;
            TransactionDocumentId = transactionDocumentId;
            CardRequestId = cardRequestId;
            CardDocumentId = cardDocumentId;
        }

        public BankingAppDbContext Db { get; }
        public Guid OwnerId { get; }
        public Guid TransactionId { get; }
        public Guid TransactionDocumentId { get; }
        public Guid CardRequestId { get; }
        public Guid CardDocumentId { get; }
        public IReadOnlyList<string> Statements => _interceptor.Statements;

        public TransactionService Transactions()
        {
            _interceptor.Statements.Clear();
            return new TransactionService(
                Db, new CurrentUser(OwnerId), new DemoCurrencyConversionService());
        }

        public CardService Cards()
        {
            _interceptor.Statements.Clear();
            return new CardService(Db, new CurrentUser(OwnerId));
        }

        public void AssertNoStatementSelectedContent()
        {
            Assert.NotEmpty(Statements);
            var offender = Statements.FirstOrDefault(SelectsContentColumn);
            Assert.True(
                offender is null,
                $"A list/detail statement selected the document blob:{Environment.NewLine}{offender}");
        }

        /// <summary>
        /// Matches the quoted <c>"Content"</c> column only, so the legitimate
        /// <c>"ContentType"</c> metadata column can never cause a false positive.
        /// </summary>
        public static bool SelectsContentColumn(string sql) =>
            Regex.IsMatch(sql, "\"Content\"(?!Type)");

        public static async Task<SqlFixture> CreateAsync()
        {
            var connection = new SqliteConnection("DataSource=:memory:");
            await connection.OpenAsync();
            // The model declares a SQL Server collation on the account type code.
            // SQLite needs it registered by name before it will prepare the DDL.
            connection.CreateCollation(
                "Latin1_General_100_CI_AS",
                (left, right) => string.Compare(left, right, StringComparison.OrdinalIgnoreCase));
            var interceptor = new CapturingInterceptor();
            var db = new SqliteTestContext(
                new DbContextOptionsBuilder<BankingAppDbContext>()
                    .UseSqlite(connection)
                    .AddInterceptors(interceptor)
                    .Options);
            await db.Database.EnsureCreatedAsync();

            var owner = new User
            {
                Id = Guid.NewGuid(), FirstName = "Owner", LastName = "Customer",
                Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
                PasswordHash = "hash", Role = AppRoles.Customer,
                Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
            };
            var account = new Account
            {
                Id = Guid.NewGuid(), UserId = owner.Id, AccountNumber = "BA-SQL-CHECKING",
                AccountTypeId = AccountTypeCodes.CheckingId, Currency = "BAM",
                Balance = 500m, Status = AccountStatus.Active, CreatedAtUtc = DateTime.UtcNow
            };
            var transaction = new Transaction
            {
                Id = Guid.NewGuid(), AccountId = account.Id, ReferenceNumber = "TRX-SQL-1",
                Amount = -25m, Type = TransactionType.Transfer, Description = "With document",
                Status = TransactionStatus.DocumentsRequested, IsHighRiskReview = true,
                CreatedAtUtc = DateTime.UtcNow
            };
            var transactionDocument = new TransactionDocument
            {
                Id = Guid.NewGuid(), TransactionId = transaction.Id, FileName = "proof.pdf",
                ContentType = "application/pdf", SizeBytes = Content.LongLength,
                Content = Content, UploadedAtUtc = DateTime.UtcNow
            };
            var cardRequest = new CardRequest
            {
                Id = Guid.NewGuid(), UserId = owner.Id, CardholderName = "Owner Customer",
                Currency = "BAM", DocumentNumber = "ID-1", DeliveryAddress = "Street 1",
                Note = string.Empty, Status = CardRequestStatus.DocumentsRequested,
                CreatedAtUtc = DateTime.UtcNow
            };
            var cardDocument = new CardRequestDocument
            {
                Id = Guid.NewGuid(), CardRequestId = cardRequest.Id,
                FileName = "card-proof.pdf", ContentType = "application/pdf",
                SizeBytes = Content.LongLength, Content = Content,
                UploadedAtUtc = DateTime.UtcNow
            };

            db.Users.Add(owner);
            db.Accounts.Add(account);
            db.Transactions.Add(transaction);
            db.TransactionDocuments.Add(transactionDocument);
            db.CardRequests.Add(cardRequest);
            db.CardRequestDocuments.Add(cardDocument);
            await db.SaveChangesAsync();
            db.ChangeTracker.Clear();

            return new SqlFixture(connection, db, interceptor, owner.Id, transaction.Id,
                transactionDocument.Id, cardRequest.Id, cardDocument.Id);
        }

        public async ValueTask DisposeAsync()
        {
            await Db.DisposeAsync();
            await _connection.DisposeAsync();
        }
    }

    /// <summary>
    /// The real model, minus the SQL Server specific DDL that SQLite cannot parse.
    /// Only index filters are dropped; every table, column and type mapping the SQL
    /// under test depends on stays exactly as production declares it.
    /// </summary>
    private sealed class SqliteTestContext(DbContextOptions<BankingAppDbContext> options)
        : BankingAppDbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            foreach (var index in modelBuilder.Model
                .GetEntityTypes()
                .SelectMany(entity => entity.GetIndexes()))
            {
                index.SetFilter(null);
            }
        }
    }

    private sealed class CapturingInterceptor : DbCommandInterceptor
    {
        public List<string> Statements { get; } = [];

        public override InterceptionResult<DbDataReader> ReaderExecuting(
            DbCommand command,
            CommandEventData eventData,
            InterceptionResult<DbDataReader> result)
        {
            Statements.Add(command.CommandText);
            return result;
        }

        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
            DbCommand command,
            CommandEventData eventData,
            InterceptionResult<DbDataReader> result,
            CancellationToken cancellationToken = default)
        {
            Statements.Add(command.CommandText);
            return ValueTask.FromResult(result);
        }
    }

    private sealed class CurrentUser(Guid id, bool admin = false) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => admin;
    }
}
