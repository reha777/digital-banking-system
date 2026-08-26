using BankingApp.Api.Controllers;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Transactions;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class TransactionAuthorizationTests
{
    [Fact]
    public async Task Customer_cannot_list_or_read_another_customers_transaction()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.OtherCustomer.Id);

        var page = await service.GetAsync(new TransactionQueryRequest());

        Assert.Empty(page.Items);
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetByIdAsync(fixture.Transaction.Id));
    }

    [Fact]
    public async Task Customer_cannot_access_or_download_another_customers_document()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.OtherCustomer.Id);

        await Assert.ThrowsAsync<NotFoundException>(() => service.UploadDocumentAsync(
            fixture.Transaction.Id,
            new TransactionDocumentUploadRequest
            {
                FileName = "proof.txt", ContentType = "text/plain", Content = [1]
            }));
        await Assert.ThrowsAsync<NotFoundException>(() => service.DownloadDocumentAsync(
            fixture.Transaction.Id, fixture.Document.Id));
    }

    [Fact]
    public async Task Admin_can_list_read_and_download_administrated_transaction_data()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.Admin.Id, isAdmin: true);

        Assert.Single((await service.GetAsync(new TransactionQueryRequest())).Items);
        Assert.Equal(fixture.Transaction.Id, (await service.GetByIdAsync(fixture.Transaction.Id)).Id);
        Assert.Equal(fixture.Document.Content, (await service.DownloadDocumentAsync(
            fixture.Transaction.Id, fixture.Document.Id)).Content);
    }

    [Theory]
    [InlineData(nameof(TransactionsController.ApproveReview))]
    [InlineData(nameof(TransactionsController.RejectReview))]
    [InlineData(nameof(TransactionsController.RequestDocuments))]
    public void Review_mutations_require_admin_role(string actionName)
    {
        var action = typeof(TransactionsController).GetMethod(actionName)!;
        var authorize = Assert.Single(action.GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>());
        Assert.Equal(AppRoles.Admin, authorize.Roles);
    }

    [Fact]
    public async Task Non_admin_service_cannot_execute_review_mutations()
    {
        await using var fixture = await Fixture.CreateAsync();
        var service = fixture.Service(fixture.Owner.Id);
        var request = new TransactionReviewRequest { AdminNote = "not allowed" };

        await Assert.ThrowsAsync<BusinessException>(() => service.ApproveReviewAsync(fixture.Transaction.Id, request));
        await Assert.ThrowsAsync<BusinessException>(() => service.RejectReviewAsync(fixture.Transaction.Id, request));
        await Assert.ThrowsAsync<BusinessException>(() => service.RequestDocumentsAsync(
            fixture.Transaction.Id, new TransactionDocumentsRequest { AdminNote = "not allowed" }));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, User owner, User otherCustomer, User admin,
            Transaction transaction, TransactionDocument document)
        {
            Db = db; Owner = owner; OtherCustomer = otherCustomer; Admin = admin;
            Transaction = transaction; Document = document;
        }

        public BankingAppDbContext Db { get; }
        public User Owner { get; }
        public User OtherCustomer { get; }
        public User Admin { get; }
        public Transaction Transaction { get; }
        public TransactionDocument Document { get; }
        public TransactionService Service(Guid userId, bool isAdmin = false) =>
            new(Db, new CurrentUser(userId, isAdmin), new DemoCurrencyConversionService());

        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            var owner = User("Owner", AppRoles.Customer);
            var other = User("Other", AppRoles.Customer);
            var admin = User("Admin", AppRoles.Admin);
            var account = new Account
            {
                Id = Guid.NewGuid(), UserId = owner.Id, User = owner,
                AccountNumber = "owner-account", Currency = "USD", Balance = 100,
                AccountType = AccountType.Checking, CreatedAtUtc = DateTime.UtcNow
            };
            var transaction = new Transaction
            {
                Id = Guid.NewGuid(), AccountId = account.Id, Account = account,
                SourceAccountId = account.Id, DestinationAccountId = Guid.NewGuid(),
                ReferenceNumber = "AUTH-TEST", Amount = -10, Type = TransactionType.Transfer,
                Description = "Review", Status = TransactionStatus.DocumentsRequested,
                IsHighRiskReview = true, CreatedAtUtc = DateTime.UtcNow
            };
            var document = new TransactionDocument
            {
                Id = Guid.NewGuid(), TransactionId = transaction.Id, Transaction = transaction,
                FileName = "proof.txt", ContentType = "text/plain", Content = [1, 2, 3],
                SizeBytes = 3, UploadedAtUtc = DateTime.UtcNow
            };
            transaction.Documents.Add(document);
            db.Users.AddRange(owner, other, admin);
            db.Accounts.Add(account);
            db.Transactions.Add(transaction);
            await db.SaveChangesAsync();
            return new Fixture(db, owner, other, admin, transaction, document);
        }

        private static User User(string name, string role) => new()
        {
            Id = Guid.NewGuid(), FirstName = name, LastName = "User",
            Email = $"{Guid.NewGuid()}@test.com", PhoneNumber = "+38761000000",
            PasswordHash = "hash", Role = role, Status = CustomerStatus.Active,
            CreatedAtUtc = DateTime.UtcNow
        };

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class CurrentUser(Guid userId, bool isAdmin) : ICurrentUserService
    {
        public Guid UserId => userId;
        public bool IsAdmin => isAdmin;
    }
}
