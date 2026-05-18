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

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            ConfigureUsers(modelBuilder);
            ConfigureAccounts(modelBuilder);
            ConfigureTransactions(modelBuilder);
            SeedData(modelBuilder);
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

                entity.Property(user => user.PasswordHash)
                    .HasMaxLength(500)
                    .IsRequired();

                entity.Property(user => user.Role)
                    .HasMaxLength(50)
                    .IsRequired();

                entity.Property(user => user.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(user => user.Email)
                    .IsUnique();

                entity.HasMany(user => user.Accounts)
                    .WithOne(account => account.User)
                    .HasForeignKey(account => account.UserId)
                    .OnDelete(DeleteBehavior.Restrict);
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

                entity.Property(transaction => transaction.Amount)
                    .HasPrecision(18, 2)
                    .IsRequired();

                entity.Property(transaction => transaction.Description)
                    .HasMaxLength(250)
                    .IsRequired();

                entity.Property(transaction => transaction.Status)
                    .HasConversion<string>()
                    .HasMaxLength(25)
                    .IsRequired();

                entity.Property(transaction => transaction.CreatedAtUtc)
                    .IsRequired();

                entity.HasIndex(transaction => transaction.ReferenceNumber)
                    .IsUnique();
            });
        }

        private static void SeedData(ModelBuilder modelBuilder)
        {
            var userId = Guid.Parse("9a99a021-b892-4f5a-bd98-36a5afbf0c79");
            var checkingAccountId = Guid.Parse("dbdd0766-a83e-4a7d-944c-af7d0373ff50");
            var savingsAccountId = Guid.Parse("6e4ac9f4-28d0-4f6a-b8c4-c7937f9a5ae3");
            var initialDepositId = Guid.Parse("b8e0dbf7-536f-4301-99c7-5b3a1e03f450");
            var savingsDepositId = Guid.Parse("fd261404-8751-4faa-bffa-cdf7ea592903");
            var createdAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            const string testPasswordHash = "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=";

            modelBuilder.Entity<User>().HasData(new User
            {
                Id = userId,
                FirstName = "Demo",
                LastName = "Customer",
                Email = "mobile@bankingapp.local",
                PasswordHash = testPasswordHash,
                Role = AppRoles.Customer,
                CreatedAtUtc = createdAtUtc
            });

            modelBuilder.Entity<Account>().HasData(
                new Account
                {
                    Id = checkingAccountId,
                    UserId = userId,
                    AccountNumber = "BA-000001-CHECKING",
                    AccountType = AccountType.Checking,
                    Balance = 1250.00m,
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
                });

            modelBuilder.Entity<Transaction>().HasData(
                new Transaction
                {
                    Id = initialDepositId,
                    AccountId = checkingAccountId,
                    ReferenceNumber = "TXN-20260101-0001",
                    Amount = 1250.00m,
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
                    Description = "Initial savings deposit",
                    Status = TransactionStatus.Completed,
                    CreatedAtUtc = createdAtUtc
                });
        }
    }
}
