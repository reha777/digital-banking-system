using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRecipientDemoCard : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "BankCards",
                columns: new[] { "Id", "AccountId", "Brand", "CardNumber", "CardholderName", "CreatedAtUtc", "Cvv", "ExpiryDate", "Status" },
                values: new object[] { new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5897"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), "Mastercard", "5425233430109903", "Yamilet Recipient", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "417", new DateTime(2030, 9, 24, 0, 0, 0, 0, DateTimeKind.Utc), "Active" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5897"));
        }
    }
}
