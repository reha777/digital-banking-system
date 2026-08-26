using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;
using BankingApp.Domain.Constants;
using Microsoft.EntityFrameworkCore;

namespace BankingApp.Infrastructure.Persistence
{
    public class BankingAppDbContext(DbContextOptions<BankingAppDbContext> options) : DbContext(options)
    {
        public DbSet<User> Users => Set<User>();

        public DbSet<Account> Accounts => Set<Account>();

        public DbSet<Transaction> Transactions => Set<Transaction>();

        public DbSet<TransactionDocument> TransactionDocuments => Set<TransactionDocument>();

        public DbSet<BankCard> BankCards => Set<BankCard>();

        public DbSet<CardRequest> CardRequests => Set<CardRequest>();

        public DbSet<CardRequestDocument> CardRequestDocuments => Set<CardRequestDocument>();

        public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
        public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
        public DbSet<Notification> Notifications => Set<Notification>();

        public DbSet<AccessTokenRevocation> AccessTokenRevocations => Set<AccessTokenRevocation>();
        public DbSet<SystemSettings> SystemSettings => Set<SystemSettings>();
        public DbSet<AdminUserPreferences> AdminUserPreferences => Set<AdminUserPreferences>();
        public DbSet<LoanProduct> LoanProducts => Set<LoanProduct>();
        public DbSet<LoanApplication> LoanApplications => Set<LoanApplication>();
        public DbSet<Loan> Loans => Set<Loan>();
        public DbSet<LoanInstallment> LoanInstallments => Set<LoanInstallment>();
        public DbSet<LoanPayment> LoanPayments => Set<LoanPayment>();
        public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
        public DbSet<ReferenceDataItem> ReferenceDataItems => Set<ReferenceDataItem>();
        public DbSet<ReportJob> ReportJobs => Set<ReportJob>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            ConfigureUsers(modelBuilder);
            ConfigureAccounts(modelBuilder);
            ConfigureTransactions(modelBuilder);
            ConfigureTransactionDocuments(modelBuilder);
            ConfigureBankCards(modelBuilder);
            ConfigureCardRequests(modelBuilder);
            ConfigureCardRequestDocuments(modelBuilder);
            ConfigureRefreshTokens(modelBuilder);
            ConfigurePasswordResetTokens(modelBuilder);
            ConfigureNotifications(modelBuilder);
            ConfigureAccessTokenRevocations(modelBuilder);
            ConfigureSettings(modelBuilder);
            ConfigureLoans(modelBuilder);
            ConfigureAuditLogs(modelBuilder);
            ConfigureReferenceData(modelBuilder);
            ConfigureReportJobs(modelBuilder);
            SeedData(modelBuilder);
        }

        private static void ConfigureAuditLogs(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.ToTable("AuditLogs");
                entity.HasKey(x => x.Id);
                entity.Property(x => x.ActorName).HasMaxLength(160).IsRequired();
                entity.Property(x => x.ActorRole).HasMaxLength(30).IsRequired();
                entity.Property(x => x.Action).HasMaxLength(80).IsRequired();
                entity.Property(x => x.EntityType).HasMaxLength(80).IsRequired();
                entity.Property(x => x.EntityId).HasMaxLength(100).IsRequired();
                entity.Property(x => x.Description).HasMaxLength(500).IsRequired();
                entity.Property(x => x.Reason).HasMaxLength(500);
                entity.Property(x => x.OldValue).HasMaxLength(250);
                entity.Property(x => x.NewValue).HasMaxLength(250);
                entity.Property(x => x.CorrelationId).HasMaxLength(100);
                entity.HasIndex(x => x.CreatedAtUtc);
                entity.HasIndex(x => x.ActorUserId);
                entity.HasIndex(x => new { x.Action, x.EntityType });
                entity.HasIndex(x => new { x.EntityType, x.EntityId });
            });
        }

        private static void ConfigureReferenceData(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ReferenceDataItem>(entity =>
            {
                entity.ToTable("ReferenceDataItems");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.Type).HasMaxLength(40).IsRequired();
                entity.Property(value => value.Code).HasMaxLength(40).IsRequired();
                entity.Property(value => value.Name).HasMaxLength(120).IsRequired();
                entity.Property(value => value.Description).HasMaxLength(500);
                entity.HasIndex(value => new { value.Type, value.Code }).IsUnique();
                entity.HasIndex(value => new { value.Type, value.IsActive, value.SortOrder });
            });
        }
        private static void ConfigureReportJobs(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ReportJob>(entity =>
            {
                entity.ToTable("ReportJobs"); entity.HasKey(x => x.Id);
                entity.Property(x => x.Type).HasConversion<string>().HasMaxLength(40).IsRequired();
                entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(20).IsRequired();
                entity.Property(x => x.FileName).HasMaxLength(180); entity.Property(x => x.StoragePath).HasMaxLength(500);
                entity.Property(x => x.ErrorMessage).HasMaxLength(500); entity.Property(x => x.FilterJson).IsRequired();
                entity.Property(x => x.CorrelationId).HasMaxLength(100); entity.HasIndex(x => x.RequestedAtUtc);
                entity.HasIndex(x => x.Status); entity.HasOne(x => x.RequestedByUser).WithMany().HasForeignKey(x => x.RequestedByUserId).OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureSettings(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<SystemSettings>(entity =>
            {
                entity.ToTable("SystemSettings");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.SystemName).HasMaxLength(120).IsRequired();
                entity.Property(value => value.SystemShortName).HasMaxLength(20).IsRequired();
                entity.Property(value => value.CompanyName).HasMaxLength(160).IsRequired();
                entity.Property(value => value.CompanyEmail).HasMaxLength(256).IsRequired();
                entity.Property(value => value.CompanyPhone).HasMaxLength(30).IsRequired();
                entity.Property(value => value.Timezone).HasMaxLength(80).IsRequired();
            });

            modelBuilder.Entity<AdminUserPreferences>(entity =>
            {
                entity.ToTable("AdminUserPreferences");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.ThemeMode).HasMaxLength(10).IsRequired();
                entity.Property(value => value.SidebarStyle).HasMaxLength(12).IsRequired();
                entity.Property(value => value.DateFormat).HasMaxLength(20).IsRequired();
                entity.Property(value => value.TimeFormat).HasMaxLength(10).IsRequired();
                entity.Property(value => value.FirstDayOfWeek).HasMaxLength(10).IsRequired();
                entity.Property(value => value.NumberFormat).HasMaxLength(20).IsRequired();
                entity.Property(value => value.Timezone).HasMaxLength(80).IsRequired();
                entity.HasIndex(value => value.UserId).IsUnique();
                entity.HasOne(value => value.User).WithOne().HasForeignKey<AdminUserPreferences>(value => value.UserId).OnDelete(DeleteBehavior.Cascade);
            });
        }

        private static void ConfigureUsers(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.ToTable("Users");

                entity.HasKey(user => user.Id);

                entity.Property(user => user.FirstName)
                    .HasMaxLength(100)
                    .IsRequired();

                entity.Property(user => user.LastName)
                    .HasMaxLength(100)
                    .IsRequired();

                entity.Property(user => user.Email)
                    .HasMaxLength(256)
                    .IsRequired();

                entity.Property(user => user.PhoneNumber)
                    .HasMaxLength(30)
                    .IsRequired();

                entity.Property(user => user.PasswordHash)
                    .HasMaxLength(500)
                    .IsRequired();

                entity.Property(user => user.ProfilePhotoContentType)
                    .HasMaxLength(20);

                entity.Property(user => user.Role)
                    .HasMaxLength(50)
                    .IsRequired();

                entity.Property(user => user.Status)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(user => user.IsDeleted)
                    .IsRequired();

                entity.Property(user => user.DeletedAtUtc);

                entity.Property(user => user.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(user => user.Email)
                    .IsUnique();

                entity.HasMany(user => user.Accounts)
                    .WithOne(account => account.User)
                    .HasForeignKey(account => account.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasMany(user => user.RefreshTokens)
                    .WithOne(refreshToken => refreshToken.User)
                    .HasForeignKey(refreshToken => refreshToken.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }

        private static void ConfigureAccounts(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Account>(entity =>
            {
                entity.ToTable("Accounts");

                entity.HasKey(account => account.Id);

                entity.Property(account => account.AccountNumber)
                    .HasMaxLength(34)
                    .IsRequired();

                entity.Property(account => account.AccountType)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(account => account.Balance)
                    .HasPrecision(18, 2)
                    .IsRequired();

                entity.Property(account => account.Currency)
                    .HasMaxLength(3)
                    .IsRequired();

                entity.Property(account => account.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(account => account.AccountNumber)
                    .IsUnique();

                entity.HasMany(account => account.Transactions)
                    .WithOne(transaction => transaction.Account)
                    .HasForeignKey(transaction => transaction.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(account => account.Card)
                    .WithOne(card => card.Account)
                    .HasForeignKey<BankCard>(card => card.AccountId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }

        private static void ConfigureTransactions(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Transaction>(entity =>
            {
                entity.ToTable("Transactions");

                entity.HasKey(transaction => transaction.Id);

                entity.Property(transaction => transaction.ReferenceNumber)
                    .HasMaxLength(50)
                    .IsRequired();

                entity.Property(transaction => transaction.SourceAccountId);

                entity.Property(transaction => transaction.DestinationAccountId);

                entity.Property(transaction => transaction.Amount)
                    .HasPrecision(18, 2)
                    .IsRequired();

                entity.Property(transaction => transaction.Type)
                    .HasConversion<string>()
                    .HasMaxLength(30)
                    .HasDefaultValue(TransactionType.Transfer)
                    .HasSentinel((TransactionType)0)
                    .IsRequired();

                entity.Property(transaction => transaction.TransferAmount)
                    .HasPrecision(18, 2);

                entity.Property(transaction => transaction.TransferCurrency)
                    .HasMaxLength(3);

                entity.Property(transaction => transaction.DestinationAmount)
                    .HasPrecision(18, 2);

                entity.Property(transaction => transaction.Description)
                    .HasMaxLength(250)
                    .IsRequired();

                entity.Property(transaction => transaction.Status)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(transaction => transaction.ReviewReason)
                    .HasMaxLength(500);

                entity.Property(transaction => transaction.DocumentsRequestNote)
                    .HasMaxLength(500);

                entity.Property(transaction => transaction.AdminNote)
                    .HasMaxLength(500);

                entity.Property(transaction => transaction.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(transaction => transaction.ReferenceNumber)
                    .IsUnique(false);
                entity.HasOne(transaction => transaction.TransactionCategory).WithMany()
                    .HasForeignKey(transaction => transaction.TransactionCategoryId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureTransactionDocuments(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TransactionDocument>(entity =>
            {
                entity.ToTable("TransactionDocuments");

                entity.HasKey(document => document.Id);

                entity.Property(document => document.FileName)
                    .HasMaxLength(180)
                    .IsRequired();

                entity.Property(document => document.ContentType)
                    .HasMaxLength(120)
                    .IsRequired();

                entity.Property(document => document.Content)
                    .IsRequired();

                entity.Property(document => document.UploadedAtUtc)
                    .IsRequired();

                entity.HasOne(document => document.Transaction)
                    .WithMany(transaction => transaction.Documents)
                    .HasForeignKey(document => document.TransactionId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(document => document.DocumentType).WithMany()
                    .HasForeignKey(document => document.DocumentTypeId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureBankCards(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<BankCard>(entity =>
            {
                entity.ToTable("BankCards");

                entity.HasKey(card => card.Id);

                entity.Property(card => card.CardNumber)
                    .HasMaxLength(19)
                    .IsRequired();

                entity.Property(card => card.CardholderName)
                    .HasMaxLength(160)
                    .IsRequired();

                entity.Property(card => card.Cvv)
                    .HasMaxLength(4)
                    .IsRequired();

                entity.Property(card => card.Brand)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(card => card.Status)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(card => card.ExpiryDate)
                    .IsRequired();

                entity.Property(card => card.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(card => card.AccountId)
                    .IsUnique();

                entity.HasIndex(card => card.CardNumber)
                    .IsUnique();
            });
        }

        private static void ConfigureCardRequests(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<CardRequest>(entity =>
            {
                entity.ToTable("CardRequests");

                entity.HasKey(request => request.Id);

                entity.Property(request => request.CardholderName)
                    .HasMaxLength(160)
                    .IsRequired();

                entity.Property(request => request.Currency)
                    .HasMaxLength(3)
                    .IsRequired();

                entity.Property(request => request.DocumentNumber)
                    .HasMaxLength(80)
                    .IsRequired();

                entity.Property(request => request.DeliveryAddress)
                    .HasMaxLength(250)
                    .IsRequired();

                entity.Property(request => request.Note)
                    .HasMaxLength(500)
                    .IsRequired();

                entity.Property(request => request.Status)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(request => request.AdminNote)
                    .HasMaxLength(500);

                entity.Property(request => request.DocumentsRequestNote)
                    .HasMaxLength(500);

                entity.Property(request => request.CreatedAtUtc)
                    .IsRequired();

                entity.HasOne(request => request.User)
                    .WithMany(user => user.CardRequests)
                    .HasForeignKey(request => request.UserId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(request => request.ApprovedAccount)
                    .WithMany()
                    .HasForeignKey(request => request.ApprovedAccountId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(request => request.ApprovedCard)
                    .WithMany()
                    .HasForeignKey(request => request.ApprovedCardId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        private static void ConfigureCardRequestDocuments(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<CardRequestDocument>(entity =>
            {
                entity.ToTable("CardRequestDocuments");

                entity.HasKey(document => document.Id);

                entity.Property(document => document.FileName)
                    .HasMaxLength(180)
                    .IsRequired();

                entity.Property(document => document.ContentType)
                    .HasMaxLength(120)
                    .IsRequired();

                entity.Property(document => document.SizeBytes)
                    .IsRequired();

                entity.Property(document => document.Content)
                    .IsRequired();

                entity.Property(document => document.UploadedAtUtc)
                    .IsRequired();

                entity.HasOne(document => document.CardRequest)
                    .WithMany(request => request.Documents)
                    .HasForeignKey(document => document.CardRequestId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(document => document.DocumentType).WithMany()
                    .HasForeignKey(document => document.DocumentTypeId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigureNotifications(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Notification>(entity =>
            {
                entity.ToTable("Notifications"); entity.HasKey(value => value.Id);
                entity.Property(value => value.Type).HasConversion<string>().HasMaxLength(60).IsRequired();
                entity.Property(value => value.Title).HasMaxLength(140).IsRequired();
                entity.Property(value => value.Message).HasMaxLength(500).IsRequired();
                entity.Property(value => value.EntityType).HasMaxLength(60);
                entity.HasIndex(value => new { value.UserId, value.CreatedAtUtc });
                entity.HasIndex(value => new { value.UserId, value.IsRead });
                entity.HasIndex(value => new { value.UserId, value.Type, value.EntityType, value.EntityId }).IsUnique().HasFilter("[EntityType] IS NOT NULL AND [EntityId] IS NOT NULL");
                entity.HasOne(value => value.User).WithMany(value => value.Notifications).HasForeignKey(value => value.UserId).OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void ConfigurePasswordResetTokens(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<PasswordResetToken>(entity =>
            {
                entity.ToTable("PasswordResetTokens"); entity.HasKey(value => value.Id);
                entity.Property(value => value.TokenHash).HasMaxLength(64).IsRequired();
                entity.Property(value => value.RowVersion).IsRowVersion();
                entity.HasIndex(value => value.TokenHash).IsUnique();
                entity.HasIndex(value => new { value.UserId, value.ExpiresAtUtc });
                entity.HasOne(value => value.User).WithMany(value => value.PasswordResetTokens).HasForeignKey(value => value.UserId).OnDelete(DeleteBehavior.Cascade);
            });
        }

        private static void ConfigureRefreshTokens(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<RefreshToken>(entity =>
            {
                entity.ToTable("RefreshTokens");

                entity.HasKey(refreshToken => refreshToken.Id);

                entity.Property(refreshToken => refreshToken.TokenHash)
                    .HasMaxLength(128)
                    .IsRequired();

                entity.Property(refreshToken => refreshToken.ExpiresAtUtc)
                    .IsRequired();

                entity.Property(refreshToken => refreshToken.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(refreshToken => refreshToken.TokenHash)
                    .IsUnique();
            });
        }

        private static void ConfigureAccessTokenRevocations(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<AccessTokenRevocation>(entity =>
            {
                entity.ToTable("AccessTokenRevocations");

                entity.HasKey(revocation => revocation.Id);

                entity.Property(revocation => revocation.TokenId)
                    .HasMaxLength(100)
                    .IsRequired();

                entity.Property(revocation => revocation.ExpiresAtUtc)
                    .IsRequired();

                entity.Property(revocation => revocation.RevokedAtUtc)
                    .IsRequired();

                entity.HasIndex(revocation => revocation.TokenId)
                    .IsUnique();
            });
        }

        private static void ConfigureLoans(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<LoanProduct>(entity =>
            {
                entity.ToTable("LoanProducts");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.Name).HasMaxLength(120).IsRequired();
                entity.Property(value => value.Description).HasMaxLength(500).IsRequired();
                entity.Property(value => value.Currency).HasMaxLength(3).IsRequired();
                entity.Property(value => value.MinPrincipal).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.MaxPrincipal).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.AnnualInterestRate).HasPrecision(9, 6).IsRequired();
                entity.HasIndex(value => value.IsActive);
                entity.HasIndex(value => value.Currency);
            });

            modelBuilder.Entity<LoanApplication>(entity =>
            {
                entity.ToTable("LoanApplications");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.Principal).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Currency).HasMaxLength(3).IsRequired();
                entity.Property(value => value.AnnualInterestRateSnapshot).HasPrecision(9, 6).IsRequired();
                entity.Property(value => value.EstimatedMonthlyPayment).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.EstimatedTotalRepayment).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.EstimatedTotalInterest).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Status).HasConversion<string>().HasMaxLength(25).IsRequired();
                entity.Property(value => value.AdminNote).HasMaxLength(500);
                entity.Property(value => value.RowVersion).IsRowVersion();
                entity.HasIndex(value => new { value.UserId, value.Status });
                entity.HasIndex(value => new { value.Status, value.SubmittedAtUtc });
                entity.HasIndex(value => new { value.UserId, value.ClientRequestId }).IsUnique();
                entity.HasIndex(value => value.UserId).IsUnique().HasFilter("[Status] = N'Pending'");
                entity.HasOne(value => value.User).WithMany(value => value.LoanApplications)
                    .HasForeignKey(value => value.UserId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.LoanProduct).WithMany(value => value.Applications)
                    .HasForeignKey(value => value.LoanProductId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.DestinationAccount).WithMany(value => value.LoanApplications)
                    .HasForeignKey(value => value.DestinationAccountId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.LoanPurpose).WithMany()
                    .HasForeignKey(value => value.LoanPurposeId).OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<Loan>(entity =>
            {
                entity.ToTable("Loans");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.OriginalPrincipal).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.OutstandingPrincipal).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Currency).HasMaxLength(3).IsRequired();
                entity.Property(value => value.AnnualInterestRate).HasPrecision(9, 6).IsRequired();
                entity.Property(value => value.MonthlyPayment).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.TotalRepayment).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.TotalPaid).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Status).HasConversion<string>().HasMaxLength(25).IsRequired();
                entity.Property(value => value.RowVersion).IsRowVersion();
                entity.HasIndex(value => value.LoanApplicationId).IsUnique();
                entity.HasIndex(value => new { value.UserId, value.Status });
                entity.HasIndex(value => value.UserId).IsUnique().HasFilter("[Status] = N'Active'");
                entity.HasOne(value => value.LoanApplication).WithOne(value => value.Loan)
                    .HasForeignKey<Loan>(value => value.LoanApplicationId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.User).WithMany(value => value.Loans)
                    .HasForeignKey(value => value.UserId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.DestinationAccount).WithMany(value => value.Loans)
                    .HasForeignKey(value => value.DestinationAccountId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.DisbursementTransaction).WithMany()
                    .HasForeignKey(value => value.DisbursementTransactionId).OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<LoanInstallment>(entity =>
            {
                entity.ToTable("LoanInstallments");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.ScheduledAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.PrincipalAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.InterestAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.RemainingPrincipalAfter).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Status).HasConversion<string>().HasMaxLength(25).IsRequired();
                entity.HasIndex(value => new { value.LoanId, value.InstallmentNumber }).IsUnique();
                entity.HasIndex(value => new { value.LoanId, value.Status, value.DueDateUtc });
                entity.HasIndex(value => value.LoanPaymentId).IsUnique().HasFilter("[LoanPaymentId] IS NOT NULL");
                entity.HasOne(value => value.Loan).WithMany(value => value.Installments)
                    .HasForeignKey(value => value.LoanId).OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(value => value.Payment).WithMany()
                    .HasForeignKey(value => value.LoanPaymentId).OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<LoanPayment>(entity =>
            {
                entity.ToTable("LoanPayments");
                entity.HasKey(value => value.Id);
                entity.Property(value => value.Amount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.PrincipalAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.InterestAmount).HasPrecision(18, 2).IsRequired();
                entity.Property(value => value.Status).HasConversion<string>().HasMaxLength(25).IsRequired();
                entity.HasIndex(value => new { value.LoanId, value.PaidAtUtc });
                entity.HasIndex(value => new { value.LoanId, value.ClientRequestId }).IsUnique();
                entity.HasIndex(value => value.LoanInstallmentId).IsUnique();
                entity.HasIndex(value => value.TransactionId).IsUnique();
                entity.HasOne(value => value.Loan).WithMany(value => value.Payments)
                    .HasForeignKey(value => value.LoanId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.LoanInstallment).WithMany()
                    .HasForeignKey(value => value.LoanInstallmentId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.SourceAccount).WithMany(value => value.LoanPayments)
                    .HasForeignKey(value => value.SourceAccountId).OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(value => value.Transaction).WithMany()
                    .HasForeignKey(value => value.TransactionId).OnDelete(DeleteBehavior.Restrict);
            });
        }

        private static void SeedData(ModelBuilder modelBuilder)
        {
            var referenceCreatedAt = new DateTime(2026, 8, 24, 0, 0, 0, DateTimeKind.Utc);
            modelBuilder.Entity<ReferenceDataItem>().HasData(
                Reference("10000000-0000-0000-0000-000000000001", "loan-purposes", "GENERAL", "General purpose", 10, referenceCreatedAt),
                Reference("10000000-0000-0000-0000-000000000002", "loan-purposes", "HOME", "Home improvement", 20, referenceCreatedAt),
                Reference("10000000-0000-0000-0000-000000000003", "loan-purposes", "EDUCATION", "Education", 30, referenceCreatedAt),
                Reference("20000000-0000-0000-0000-000000000001", "document-types", "IDENTITY", "Identity document", 10, referenceCreatedAt),
                Reference("20000000-0000-0000-0000-000000000002", "document-types", "PROOF_OF_INCOME", "Proof of income", 20, referenceCreatedAt),
                Reference("20000000-0000-0000-0000-000000000003", "document-types", "BANK_STATEMENT", "Bank statement", 30, referenceCreatedAt),
                Reference("30000000-0000-0000-0000-000000000001", "transaction-categories", "GENERAL", "General", 10, referenceCreatedAt),
                Reference("30000000-0000-0000-0000-000000000002", "transaction-categories", "TRANSFER", "Transfer", 20, referenceCreatedAt),
                Reference("30000000-0000-0000-0000-000000000003", "transaction-categories", "LOAN", "Loan", 30, referenceCreatedAt));
            var userId = Guid.Parse("9a99a021-b892-4f5a-bd98-36a5afbf0c79");
            var adminUserId = Guid.Parse("dd72f286-0cf8-44ad-81ea-d85c5964d29d");
            var recipientUserId = Guid.Parse("f5573a40-f822-45c4-a841-b6ab5d5a0c49");
            var checkingAccountId = Guid.Parse("dbdd0766-a83e-4a7d-944c-af7d0373ff50");
            var savingsAccountId = Guid.Parse("6e4ac9f4-28d0-4f6a-b8c4-c7937f9a5ae3");
            var recipientAccountId = Guid.Parse("deed75d2-e898-4c2d-a7e3-2fa1152d7222");
            var demoCardId = Guid.Parse("a8f0f3aa-e7d3-460c-86ff-6cfe0f5105dd");
            var recipientCardId = Guid.Parse("62f3cd21-d263-40ca-ae58-07d13f7c5897");
            var savingsCardId = Guid.Parse("741fc77c-fec7-4b53-92df-d664d14935e8");
            var initialDepositId = Guid.Parse("b8e0dbf7-536f-4301-99c7-5b3a1e03f450");
            var savingsDepositId = Guid.Parse("fd261404-8751-4faa-bffa-cdf7ea592903");
            var recentTransferDebitId = Guid.Parse("4a6e449e-6397-45f6-a446-5936e882c401");
            var recentTransferCreditId = Guid.Parse("4a6e449e-6397-45f6-a446-5936e882c402");
            var transferCategoryId = Guid.Parse("30000000-0000-0000-0000-000000000002");
            var bamLoanProductId = Guid.Parse("8f8dc061-237f-4bb4-89c1-32d41dc6f001");
            var eurLoanProductId = Guid.Parse("8f8dc061-237f-4bb4-89c1-32d41dc6f002");
            var usdLoanProductId = Guid.Parse("8f8dc061-237f-4bb4-89c1-32d41dc6f003");
            var createdAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            const string testPasswordHash = "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=";
            const string adminPasswordHash = "PBKDF2-SHA256.100000.ERITFBUWFxgZGhscHR4fIA==.3+i0Vv41HWR1ofVLRyJthACrUOkA/W2oSnAkMKm57ak=";

            modelBuilder.Entity<User>().HasData(
                new User
                {
                    Id = userId,
                    FirstName = "Demo",
                    LastName = "Customer",
                    Email = "mobile@bankingapp.local",
                    PhoneNumber = "+38761111222",
                    PasswordHash = testPasswordHash,
                    Role = AppRoles.Customer,
                    Status = CustomerStatus.Active,
                    IsDeleted = false,
                    CreatedAtUtc = createdAtUtc
                },
                new User
                {
                    Id = adminUserId,
                    FirstName = "Desktop",
                    LastName = "Admin",
                    Email = "admin@bankingapp.local",
                    PhoneNumber = "+38762222333",
                    PasswordHash = adminPasswordHash,
                    Role = AppRoles.Admin,
                    Status = CustomerStatus.Active,
                    IsDeleted = false,
                    CreatedAtUtc = createdAtUtc
                },
                new User
                {
                    Id = recipientUserId,
                    FirstName = "Yamilet",
                    LastName = "Recipient",
                    Email = "recipient@bankingapp.local",
                    PhoneNumber = "+38763333444",
                    PasswordHash = testPasswordHash,
                    Role = AppRoles.Customer,
                    Status = CustomerStatus.Active,
                    IsDeleted = false,
                    CreatedAtUtc = createdAtUtc
                });

            modelBuilder.Entity<Account>().HasData(
                new Account
                {
                    Id = checkingAccountId,
                    UserId = userId,
                    AccountNumber = "BA-000001-CHECKING",
                    AccountType = AccountType.Checking,
                    Balance = 20000.00m,
                    Currency = "USD",
                    CreatedAtUtc = createdAtUtc
                },
                new Account
                {
                    Id = savingsAccountId,
                    UserId = userId,
                    AccountNumber = "BA-000001-SAVINGS",
                    AccountType = AccountType.Savings,
                    Balance = 5000.00m,
                    Currency = "USD",
                    CreatedAtUtc = createdAtUtc
                },
                new Account
                {
                    Id = recipientAccountId,
                    UserId = recipientUserId,
                    AccountNumber = "BA-000002-CHECKING",
                    AccountType = AccountType.Checking,
                    Balance = 350.00m,
                    Currency = "USD",
                    CreatedAtUtc = createdAtUtc
                });

            modelBuilder.Entity<BankCard>().HasData(
                new BankCard
                {
                    Id = demoCardId,
                    AccountId = checkingAccountId,
                    CardNumber = "4562112245957852",
                    CardholderName = "Demo Customer",
                    Cvv = "6986",
                    ExpiryDate = new DateTime(2030, 6, 24, 0, 0, 0, DateTimeKind.Utc),
                    Brand = CardBrand.Mastercard,
                    Status = CardStatus.Active,
                    CreatedAtUtc = createdAtUtc
                },
                new BankCard
                {
                    Id = savingsCardId,
                    AccountId = savingsAccountId,
                    CardNumber = "4562444455550001",
                    CardholderName = "Demo Customer",
                    Cvv = "315",
                    ExpiryDate = new DateTime(2030, 12, 24, 0, 0, 0, DateTimeKind.Utc),
                    Brand = CardBrand.Mastercard,
                    Status = CardStatus.Active,
                    CreatedAtUtc = createdAtUtc
                },
                new BankCard
                {
                    Id = recipientCardId,
                    AccountId = recipientAccountId,
                    CardNumber = "5425233430109903",
                    CardholderName = "Yamilet Recipient",
                    Cvv = "417",
                    ExpiryDate = new DateTime(2030, 9, 24, 0, 0, 0, DateTimeKind.Utc),
                    Brand = CardBrand.Mastercard,
                    Status = CardStatus.Active,
                    CreatedAtUtc = createdAtUtc
                });

            modelBuilder.Entity<Transaction>().HasData(
                new Transaction
                {
                    Id = initialDepositId,
                    AccountId = checkingAccountId,
                    ReferenceNumber = "TXN-20260101-0001",
                    Amount = 20050.00m,
                    Type = TransactionType.Transfer,
                    Description = "Initial checking deposit",
                    Status = TransactionStatus.Completed,
                    CreatedAtUtc = createdAtUtc
                },
                new Transaction
                {
                    Id = savingsDepositId,
                    AccountId = savingsAccountId,
                    ReferenceNumber = "TXN-20260101-0002",
                    Amount = 5000.00m,
                    Type = TransactionType.Transfer,
                    Description = "Initial savings deposit",
                    Status = TransactionStatus.Completed,
                    CreatedAtUtc = createdAtUtc
                },
                new Transaction
                {
                    Id = recentTransferDebitId,
                    AccountId = checkingAccountId,
                    SourceAccountId = checkingAccountId,
                    DestinationAccountId = recipientAccountId,
                    TransactionCategoryId = transferCategoryId,
                    ReferenceNumber = "TXN-20260825-DEMO-RECENT",
                    Amount = -50.00m,
                    Type = TransactionType.Transfer,
                    TransferAmount = 50.00m,
                    TransferCurrency = "USD",
                    DestinationAmount = 50.00m,
                    Description = "Demo transfer to Yamilet Recipient",
                    Status = TransactionStatus.Completed,
                    IsHighRiskReview = false,
                    CreatedAtUtc = new DateTime(2026, 8, 25, 12, 0, 0, DateTimeKind.Utc)
                },
                new Transaction
                {
                    Id = recentTransferCreditId,
                    AccountId = recipientAccountId,
                    SourceAccountId = checkingAccountId,
                    DestinationAccountId = recipientAccountId,
                    TransactionCategoryId = transferCategoryId,
                    ReferenceNumber = "TXN-20260825-DEMO-RECENT",
                    Amount = 50.00m,
                    Type = TransactionType.Transfer,
                    TransferAmount = 50.00m,
                    TransferCurrency = "USD",
                    DestinationAmount = 50.00m,
                    Description = "Transfer from BA-000001-CHECKING",
                    Status = TransactionStatus.Completed,
                    IsHighRiskReview = false,
                    CreatedAtUtc = new DateTime(2026, 8, 25, 12, 0, 0, DateTimeKind.Utc)
                });

            modelBuilder.Entity<LoanProduct>().HasData(
                new LoanProduct
                {
                    Id = bamLoanProductId,
                    Name = "Personal Loan BAM",
                    Description = "Fixed-rate personal loan in BAM.",
                    Currency = "BAM",
                    MinPrincipal = 1000m,
                    MaxPrincipal = 50000m,
                    AnnualInterestRate = 6.50m,
                    MinTermMonths = 6,
                    MaxTermMonths = 60,
                    TermStepMonths = 6,
                    IsActive = true,
                    CreatedAtUtc = createdAtUtc,
                    UpdatedAtUtc = createdAtUtc
                },
                new LoanProduct
                {
                    Id = eurLoanProductId,
                    Name = "Personal Loan EUR",
                    Description = "Fixed-rate personal loan in EUR.",
                    Currency = "EUR",
                    MinPrincipal = 500m,
                    MaxPrincipal = 25000m,
                    AnnualInterestRate = 5.75m,
                    MinTermMonths = 6,
                    MaxTermMonths = 60,
                    TermStepMonths = 6,
                    IsActive = true,
                    CreatedAtUtc = createdAtUtc,
                    UpdatedAtUtc = createdAtUtc
                },
                new LoanProduct
                {
                    Id = usdLoanProductId,
                    Name = "Personal Loan USD",
                    Description = "Fixed-rate personal loan in USD.",
                    Currency = "USD",
                    MinPrincipal = 500m,
                    MaxPrincipal = 25000m,
                    AnnualInterestRate = 6.00m,
                    MinTermMonths = 6,
                    MaxTermMonths = 60,
                    TermStepMonths = 6,
                    IsActive = true,
                    CreatedAtUtc = createdAtUtc,
                    UpdatedAtUtc = createdAtUtc
                });
        }

        private static ReferenceDataItem Reference(
            string id, string type, string code, string name, int sortOrder, DateTime timestamp) => new()
            {
                Id = Guid.Parse(id),
                Type = type,
                Code = code,
                Name = name,
                IsActive = true,
                SortOrder = sortOrder,
                CreatedAtUtc = timestamp,
                UpdatedAtUtc = timestamp
            };
    }
}
