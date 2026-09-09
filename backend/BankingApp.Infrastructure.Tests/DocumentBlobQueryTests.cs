using System.Text.RegularExpressions;
using BankingApp.Application.Cards;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
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
/// Professor item 15: paginated list queries must not pull document blobs out of
/// the database. Metadata comes from projections; Content is read only by the
/// download endpoint.
/// </summary>
public sealed class DocumentBlobQueryTests
{
    /// A payload large enough that accidentally selecting it would be obvious.
    private static byte[] LargeContent() => Enumerable.Range(0, 512 * 1024)
        .Select(index => (byte)(index % 251))
        .ToArray();

    // ---------- SQL proof ----------

    [Fact]
    public void Transaction_list_sql_does_not_select_the_document_blob()
    {
        using var db = RelationalContext();

        // The exact shape TransactionService.GetAsync now uses for the page.
        var sql = db.Transactions
            .AsNoTracking()
            .Include(transaction => transaction.Account)
            .OrderByDescending(transaction => transaction.CreatedAtUtc)
            .Skip(0)
            .Take(20)
            .ToQueryString();

        AssertNoContentColumn(sql);
        Assert.DoesNotContain("TransactionDocuments", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void Transaction_document_metadata_sql_selects_only_metadata()
    {
        using var db = RelationalContext();
        var ids = new[] { Guid.NewGuid() };

        var sql = db.TransactionDocuments
            .AsNoTracking()
            .Where(document => ids.Contains(document.TransactionId))
            .Select(document => new TransactionDocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                SizeBytes = document.SizeBytes,
                UploadedAtUtc = document.UploadedAtUtc
            })
            .ToQueryString();

        AssertNoContentColumn(sql);
        Assert.Contains("[SizeBytes]", sql, StringComparison.Ordinal);
        Assert.Contains("[ContentType]", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void Card_request_list_sql_does_not_select_the_document_blob()
    {
        using var db = RelationalContext();

        var sql = db.CardRequests
            .AsNoTracking()
            .Include(request => request.User)
            .Include(request => request.ApprovedAccount)
            .Include(request => request.ApprovedCard)
            .OrderByDescending(request => request.CreatedAtUtc)
            .Skip(0)
            .Take(20)
            .ToQueryString();

        AssertNoContentColumn(sql);
        Assert.DoesNotContain("CardRequestDocuments", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void Card_document_metadata_sql_selects_only_metadata()
    {
        using var db = RelationalContext();
        var ids = new[] { Guid.NewGuid() };

        var sql = db.CardRequestDocuments
            .AsNoTracking()
            .Where(document => ids.Contains(document.CardRequestId))
            .Select(document => new CardRequestDocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                SizeBytes = document.SizeBytes,
                UploadedAtUtc = document.UploadedAtUtc
            })
            .ToQueryString();

        AssertNoContentColumn(sql);
        Assert.Contains("[SizeBytes]", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void Loan_application_metadata_sql_does_not_select_the_document_blob()
    {
        using var db = RelationalContext();
        var applicationId = Guid.NewGuid();

        var applicationSql = db.LoanApplications
            .AsNoTracking()
            .Include(value => value.User)
            .Include(value => value.LoanProduct)
            .Include(value => value.LoanPurpose)
            .ToQueryString();
        AssertNoContentColumn(applicationSql);
        Assert.DoesNotContain("LoanDocuments", applicationSql, StringComparison.Ordinal);

        var documentSql = db.LoanDocuments
            .AsNoTracking()
            .Where(document => document.LoanApplicationId == applicationId)
            .Select(document => new LoanDocumentResponse
            {
                Id = document.Id,
                FileName = document.FileName,
                ContentType = document.ContentType,
                SizeBytes = document.SizeBytes,
                UploadedAtUtc = document.UploadedAtUtc
            })
            .ToQueryString();
        AssertNoContentColumn(documentSql);
    }

    [Fact]
    public void The_download_query_is_the_one_place_that_does_select_content()
    {
        using var db = RelationalContext();
        var id = Guid.NewGuid();

        var sql = db.TransactionDocuments
            .AsNoTracking()
            .Where(document => document.Id == id)
            .Select(document => new TransactionDocumentDownloadResponse
            {
                FileName = document.FileName,
                ContentType = document.ContentType,
                Content = document.Content
            })
            .ToQueryString();

        // Guards the guard: the detector really does fire when Content is selected.
        Assert.True(SelectsContentColumn(sql));
    }

    // ---------- behaviour with a large blob ----------

    [Fact]
    public async Task Transaction_list_and_detail_return_metadata_without_the_blob()
    {
        await using var f = await Fixture.CreateAsync();
        var content = LargeContent();
        f.AddTransactionDocument(content);
        await f.SaveAsync();

        var service = f.CustomerTransactions();
        var page = await service.GetAsync(new TransactionQueryRequest());

        var listed = Assert.Single(page.Items);
        var document = Assert.Single(listed.Documents);
        Assert.Equal("proof.pdf", document.FileName);
        Assert.Equal("application/pdf", document.ContentType);
        Assert.Equal(content.LongLength, document.SizeBytes);

        var detail = await service.GetByIdAsync(f.Transaction.Id);
        Assert.Equal(content.LongLength, Assert.Single(detail.Documents).SizeBytes);

        // Nothing materialized the blob for those reads.
        Assert.DoesNotContain(
            f.Db.ChangeTracker.Entries<TransactionDocument>(),
            entry => entry.Entity.Content.Length > 0);
    }

    [Fact]
    public async Task Transaction_download_still_returns_the_exact_bytes()
    {
        await using var f = await Fixture.CreateAsync();
        var content = LargeContent();
        var documentId = f.AddTransactionDocument(content);
        await f.SaveAsync();

        var download = await f.CustomerTransactions()
            .DownloadDocumentAsync(f.Transaction.Id, documentId);

        Assert.Equal("proof.pdf", download.FileName);
        Assert.Equal("application/pdf", download.ContentType);
        Assert.Equal(content, download.Content);
    }

    [Fact]
    public async Task Another_customer_still_cannot_download_the_document()
    {
        await using var f = await Fixture.CreateAsync();
        var documentId = f.AddTransactionDocument(LargeContent());
        await f.SaveAsync();

        var intruder = new TransactionService(
            f.Db, new CurrentUser(f.Other.Id), new DemoCurrencyConversionService());

        await Assert.ThrowsAsync<NotFoundException>(() =>
            intruder.DownloadDocumentAsync(f.Transaction.Id, documentId));
    }

    [Fact]
    public async Task Card_request_list_returns_metadata_and_download_returns_bytes()
    {
        await using var f = await Fixture.CreateAsync();
        var content = LargeContent();
        var documentId = f.AddCardRequestDocument(content);
        await f.SaveAsync();

        var service = new CardService(f.Db, new CurrentUser(f.Owner.Id));
        var page = await service.GetMyRequestsAsync(new CardRequestQueryRequest());

        var listed = Assert.Single(page.Items);
        var document = Assert.Single(listed.Documents);
        Assert.Equal("card-proof.pdf", document.FileName);
        Assert.Equal(content.LongLength, document.SizeBytes);
        Assert.DoesNotContain(
            f.Db.ChangeTracker.Entries<CardRequestDocument>(),
            entry => entry.Entity.Content.Length > 0);

        var download = await service.DownloadDocumentAsync(f.CardRequest.Id, documentId);
        Assert.Equal(content, download.Content);
        Assert.Equal("card-proof.pdf", download.FileName);
    }

    private static void AssertNoContentColumn(string sql) =>
        Assert.False(
            SelectsContentColumn(sql),
            $"The generated SQL selects the document blob column:{Environment.NewLine}{sql}");

    /// <summary>
    /// Matches the bracketed <c>[Content]</c> column only, so the legitimate
    /// <c>[ContentType]</c> metadata column can never trigger a false positive.
    /// </summary>
    private static bool SelectsContentColumn(string sql) =>
        Regex.IsMatch(sql, @"\[Content\](?!Type)");

    private static BankingAppDbContext RelationalContext() =>
        new(new DbContextOptionsBuilder<BankingAppDbContext>()
            .UseSqlServer("Server=localhost;Database=item15;Trusted_Connection=True;")
            .Options);

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User other,
            Transaction transaction, CardRequest cardRequest)
        {
            Db = db; Owner = owner; Other = other;
            Transaction = transaction; CardRequest = cardRequest;
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User Other { get; }
        public Transaction Transaction { get; }
        public CardRequest CardRequest { get; }

        public TransactionService CustomerTransactions() => new(
            Db, new CurrentUser(Owner.Id), new DemoCurrencyConversionService());

        public Guid AddTransactionDocument(byte[] content)
        {
            var id = Guid.NewGuid();
            Db.TransactionDocuments.Add(new TransactionDocument
            {
                Id = id,
                TransactionId = Transaction.Id,
                FileName = "proof.pdf",
                ContentType = "application/pdf",
                SizeBytes = content.LongLength,
                Content = content,
                UploadedAtUtc = DateTime.UtcNow
            });
            return id;
        }

        public Guid AddCardRequestDocument(byte[] content)
        {
            var id = Guid.NewGuid();
            Db.CardRequestDocuments.Add(new CardRequestDocument
            {
                Id = id,
                CardRequestId = CardRequest.Id,
                FileName = "card-proof.pdf",
                ContentType = "application/pdf",
                SizeBytes = content.LongLength,
                Content = content,
                UploadedAtUtc = DateTime.UtcNow
            });
            return id;
        }

        public async Task SaveAsync()
        {
            await Db.SaveChangesAsync();
            // Force every later read to hit the store rather than the identity map.
            Db.ChangeTracker.Clear();
        }

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            db.SeedAccountTypes();
            var owner = User("Owner");
            var other = User("Other");
            var account = new Account
            {
                Id = Guid.NewGuid(), UserId = owner.Id, User = owner,
                AccountNumber = "BA-DOCS-CHECKING", AccountTypeId = AccountTypeCodes.CheckingId,
                Currency = "BAM", Balance = 500m, Status = AccountStatus.Active,
                CreatedAtUtc = DateTime.UtcNow
            };
            var transaction = new Transaction
            {
                Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
                ReferenceNumber = "TRX-DOCS-1", Amount = -25m,
                Type = TransactionType.Transfer, Description = "With document",
                Status = TransactionStatus.DocumentsRequested, IsHighRiskReview = true,
                CreatedAtUtc = DateTime.UtcNow
            };
            var cardRequest = new CardRequest
            {
                Id = Guid.NewGuid(), UserId = owner.Id, User = owner,
                CardholderName = "Owner User", Currency = "BAM",
                DocumentNumber = "ID-1", DeliveryAddress = "Street 1", Note = string.Empty,
                Status = CardRequestStatus.DocumentsRequested, CreatedAtUtc = DateTime.UtcNow
            };
            db.Users.AddRange(owner, other);
            db.Accounts.Add(account);
            db.Transactions.Add(transaction);
            db.CardRequests.Add(cardRequest);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, other, transaction, cardRequest);
        }

        private static User User(string name) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "Customer",
            Email = $"{Guid.NewGuid()}@example.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = AppRoles.Customer,
            Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid id, bool admin = false) : ICurrentUserService
    {
        public Guid UserId => id;
        public bool IsAdmin => admin;
    }
}
