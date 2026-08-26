using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class FinalMobileDemoSeed : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"),
                column: "Balance",
                value: 20000.00m);

            migrationBuilder.UpdateData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"),
                column: "Balance",
                value: 350.00m);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                column: "Amount",
                value: 20050.00m);

            migrationBuilder.InsertData(
                table: "Transactions",
                columns: new[] { "Id", "AccountId", "AdminNote", "Amount", "CreatedAtUtc", "Description", "DestinationAccountId", "DestinationAmount", "DocumentsRequestNote", "DocumentsRequestedAtUtc", "IsHighRiskReview", "ReferenceNumber", "ReviewReason", "ReviewedAtUtc", "ReviewedByUserId", "SourceAccountId", "Status", "TransactionCategoryId", "TransferAmount", "TransferCurrency", "Type" },
                values: new object[,]
                {
                    { new Guid("4a6e449e-6397-45f6-a446-5936e882c401"), new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), null, -50.00m, new DateTime(2026, 8, 25, 12, 0, 0, 0, DateTimeKind.Utc), "Demo transfer to Yamilet Recipient", new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), 50.00m, null, null, false, "TXN-20260825-DEMO-RECENT", null, null, null, new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), "Completed", new Guid("30000000-0000-0000-0000-000000000002"), 50.00m, "USD", "Transfer" },
                    { new Guid("4a6e449e-6397-45f6-a446-5936e882c402"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), null, 50.00m, new DateTime(2026, 8, 25, 12, 0, 0, 0, DateTimeKind.Utc), "Transfer from BA-000001-CHECKING", new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), 50.00m, null, null, false, "TXN-20260825-DEMO-RECENT", null, null, null, new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), "Completed", new Guid("30000000-0000-0000-0000-000000000002"), 50.00m, "USD", "Transfer" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c401"));

            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c402"));

            migrationBuilder.UpdateData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"),
                column: "Balance",
                value: 1250.00m);

            migrationBuilder.UpdateData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"),
                column: "Balance",
                value: 300.00m);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                column: "Amount",
                value: 1250.00m);
        }
    }
}
