using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDemoSavingsCard : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "BankCards",
                columns: new[] { "Id", "AccountId", "Brand", "CardNumber", "CardholderName", "CreatedAtUtc", "Cvv", "ExpiryDate", "Status" },
                values: new object[] { new Guid("741fc77c-fec7-4b53-92df-d664d14935e8"), new Guid("6e4ac9f4-28d0-4f6a-b8c4-c7937f9a5ae3"), "Mastercard", "4562444455550001", "Demo Customer", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "315", new DateTime(2030, 12, 24, 0, 0, 0, 0, DateTimeKind.Utc), "Active" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("741fc77c-fec7-4b53-92df-d664d14935e8"));
        }
    }
}
