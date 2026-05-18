using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedAdminUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "CreatedAtUtc", "Email", "FirstName", "LastName", "PasswordHash", "Role" },
                values: new object[] { new Guid("dd72f286-0cf8-44ad-81ea-d85c5964d29d"), new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "admin@bankingapp.local", "Desktop", "Admin", "PBKDF2-SHA256.100000.ERITFBUWFxgZGhscHR4fIA==.3+i0Vv41HWR1ofVLRyJthACrUOkA/W2oSnAkMKm57ak=", "Admin" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("dd72f286-0cf8-44ad-81ea-d85c5964d29d"));
        }
    }
}
