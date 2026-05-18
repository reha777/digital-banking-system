using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedTransferRecipientAccount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "CreatedAtUtc", "Email", "FirstName", "LastName", "PasswordHash", "PhoneNumber", "Role" },
                values: new object[] { new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49"), new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "recipient@bankingapp.local", "Yamilet", "Recipient", "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=", "+38763333444", "Customer" });

            migrationBuilder.InsertData(
                table: "Accounts",
                columns: new[] { "Id", "AccountNumber", "AccountType", "Balance", "CreatedAtUtc", "Currency", "UserId" },
                values: new object[] { new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), "BA-000002-CHECKING", "Checking", 300.00m, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "USD", new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49") });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"));

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49"));
        }
    }
}
