using BankingApp.Application.AuditLogs;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Common.Pagination;
using BankingApp.Application.Interfaces;
using BankingApp.Application.Loans;
using BankingApp.Domain.Constants;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Domain.Services;
using BankingApp.Infrastructure.Persistence;
using BankingApp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class LoanDocumentTests
{
    [Fact]
    public async Task Admin_request_then_owner_uploads_valid_document_and_non_owner_is_hidden()
    {
        await using var value = await Fixture.CreateAsync();
        var requested = await value.Admin.RequestDocumentAsync(value.Application.Id,
            new LoanDocumentRequest { Description = "Proof of income", Message = "Upload latest salary statement." });
        Assert.Equal(LoanApplicationStatus.DocumentsRequested, requested.Status);
        Assert.Equal(AuditLogActions.LoanDocumentRequested, value.Audit.Records.Single().Action);

        var uploaded = await value.Owner.UploadDocumentAsync(value.Application.Id,
            new LoanDocumentUploadRequest { FileName = "salary.pdf", ContentType = "application/pdf", Content = "%PDF-test"u8.ToArray() });
        Assert.Equal(LoanApplicationStatus.Pending, uploaded.Status);
        Assert.Single(uploaded.Documents);
        Assert.Equal("salary.pdf", (await value.Db.LoanDocuments.SingleAsync()).FileName);
        await Assert.ThrowsAsync<NotFoundException>(() => value.Other.GetDocumentsAsync(value.Application.Id));
        Assert.Contains(value.Audit.Records, record => record.Action == AuditLogActions.LoanDocumentUploaded);
        var notifications = await value.Db.Notifications.OrderBy(item => item.CreatedAtUtc).ToListAsync();
        var requestNotification = Assert.Single(notifications, item => item.Type == NotificationType.LoanDocumentRequested);
        Assert.Equal(value.OwnerId, requestNotification.UserId);
        Assert.Equal("Additional document required", requestNotification.Title);
        Assert.Contains("Proof of income", requestNotification.Message);
        var uploadNotification = Assert.Single(notifications, item => item.Type == NotificationType.LoanDocumentUploaded);
        Assert.Equal(value.AdminId, uploadNotification.UserId);
        Assert.Contains("Demo User", uploadNotification.Message);
        Assert.Contains("salary.pdf", uploadNotification.Message);
    }

    [Theory]
    [InlineData("../../secret.env", "application/pdf")]
    [InlineData("salary.exe", "application/octet-stream")]
    [InlineData("salary.pdf", "image/png")]
    public async Task Unsafe_document_is_rejected(string fileName, string contentType)
    {
        await using var value = await Fixture.CreateAsync();
        value.Application.Status = LoanApplicationStatus.DocumentsRequested;
        await value.Db.SaveChangesAsync();
        await Assert.ThrowsAsync<BusinessException>(() => value.Owner.UploadDocumentAsync(value.Application.Id,
            new LoanDocumentUploadRequest { FileName = fileName, ContentType = contentType, Content = "%PDF-test"u8.ToArray() }));
    }

    [Fact]
    public async Task Finalized_application_cannot_request_document()
    {
        await using var value = await Fixture.CreateAsync();
        value.Application.Status = LoanApplicationStatus.Approved;
        await value.Db.SaveChangesAsync();
        await Assert.ThrowsAsync<BusinessException>(() => value.Admin.RequestDocumentAsync(value.Application.Id,
            new LoanDocumentRequest { Description = "Proof", Message = "Upload proof." }));
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private Fixture(BankingAppDbContext db, LoanApplication application, User owner, User other, User admin, RecordingAudit audit)
        {
            Db = db; Application = application; Audit = audit;
            OwnerId = owner.Id; AdminId = admin.Id;
            var calc = new LoanCalculationService();
            var notifications = new NotificationWriter(db);
            Admin = new AdminLoanService(db, new CurrentUser(admin.Id, true), calc, audit, notifications);
            Owner = new LoanService(db, new CurrentUser(owner.Id, false), calc, notifications, new FileValidationService(), audit);
            Other = new LoanService(db, new CurrentUser(other.Id, false), calc);
        }
        public BankingAppDbContext Db { get; }
        public LoanApplication Application { get; }
        public AdminLoanService Admin { get; }
        public LoanService Owner { get; }
        public LoanService Other { get; }
        public RecordingAudit Audit { get; }
        public Guid OwnerId { get; }
        public Guid AdminId { get; }
        public static async Task<Fixture> CreateAsync()
        {
            var db = new BankingAppDbContext(new DbContextOptionsBuilder<BankingAppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
            User User(string email) => new() { Id = Guid.NewGuid(), FirstName = "Demo", LastName = "User", Email = email,
                PhoneNumber = "+38761000000", PasswordHash = "hash", Role = AppRoles.Customer, Status = CustomerStatus.Active, CreatedAtUtc = DateTime.UtcNow };
            var owner = User("owner@test.local"); var other = User("other@test.local");
            var admin = User("admin@test.local"); admin.Role = AppRoles.Admin;
            var product = new LoanProduct { Id = Guid.NewGuid(), Name = "Test", Description = "Test", Currency = "EUR", IsActive = true,
                MinPrincipal = 100, MaxPrincipal = 10000, MinTermMonths = 6, MaxTermMonths = 24, TermStepMonths = 6,
                AnnualInterestRate = 5, CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow };
            var account = new Account { Id = Guid.NewGuid(), UserId = owner.Id, User = owner, AccountNumber = "BA-LOAN-DOC", AccountType = AccountType.Checking,
                Status = AccountStatus.Active, Balance = 0, Currency = "EUR", CreatedAtUtc = DateTime.UtcNow };
            var application = new LoanApplication { Id = Guid.NewGuid(), UserId = owner.Id, User = owner, LoanProductId = product.Id, LoanProduct = product,
                DestinationAccountId = account.Id, DestinationAccount = account, Principal = 1000, Currency = "EUR", AnnualInterestRateSnapshot = 5,
                TermMonths = 12, EstimatedMonthlyPayment = 85, EstimatedTotalInterest = 20, EstimatedTotalRepayment = 1020,
                Status = LoanApplicationStatus.Pending, SubmittedAtUtc = DateTime.UtcNow, ClientRequestId = Guid.NewGuid() };
            db.AddRange(owner, other, admin, product, account, application); await db.SaveChangesAsync();
            return new Fixture(db, application, owner, other, admin, new RecordingAudit());
        }
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private sealed class CurrentUser(Guid id, bool admin) : ICurrentUserService { public Guid UserId => id; public bool IsAdmin => admin; }
    private sealed class RecordingAudit : IAuditLogService
    {
        public List<AuditLogRecordRequest> Records { get; } = [];
        public Task RecordAsync(AuditLogRecordRequest request, CancellationToken cancellationToken = default) { Records.Add(request); return Task.CompletedTask; }
        public Task<PagedResult<AuditLogResponse>> GetAsync(AuditLogQueryRequest request, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
