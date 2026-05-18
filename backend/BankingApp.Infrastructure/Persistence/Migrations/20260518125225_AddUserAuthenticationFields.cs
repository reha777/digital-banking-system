using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUserAuthenticationFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PasswordHash",
                table: "Users",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Role",
                table: "Users",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("9a99a021-b892-4f5a-bd98-36a5afbf0c79"),
                columns: new[] { "Email", "PasswordHash", "Role" },
                values: new object[] { "mobile@bankingapp.local", "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=", "Customer" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PasswordHash",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Role",
                table: "Users");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("9a99a021-b892-4f5a-bd98-36a5afbf0c79"),
                column: "Email",
                value: "demo.customer@bankingapp.local");
        }
    }
}
