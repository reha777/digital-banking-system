using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class FinalThreeDemoAccounts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"),
                column: "Balance",
                value: 20000.00m);

            migrationBuilder.InsertData(
                table: "Accounts",
                columns: new[] { "Id", "AccountNumber", "AccountType", "Balance", "CreatedAtUtc", "Currency", "UserId" },
                values: new object[] { new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7233"), "BA-000002-SAVINGS", "Savings", 5000.00m, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "USD", new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49") });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                column: "Amount",
                value: 20000.00m);

            migrationBuilder.InsertData(
                table: "Transactions",
                columns: new[] { "Id", "AccountId", "AdminNote", "Amount", "CreatedAtUtc", "Description", "DestinationAccountId", "DestinationAmount", "DocumentsRequestNote", "DocumentsRequestedAtUtc", "IsHighRiskReview", "ReferenceNumber", "ReviewReason", "ReviewedAtUtc", "ReviewedByUserId", "SourceAccountId", "Status", "TransactionCategoryId", "TransferAmount", "TransferCurrency", "Type" },
                values: new object[,]
                {
                    { new Guid("4a6e449e-6397-45f6-a446-5936e882c403"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), null, 20000.00m, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Initial recipient checking deposit", null, null, null, null, false, "TXN-20260101-0003", null, null, null, null, "Completed", null, null, null, "Transfer" },
                    { new Guid("4a6e449e-6397-45f6-a446-5936e882c405"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), null, -50.00m, new DateTime(2026, 8, 25, 12, 5, 0, 0, DateTimeKind.Utc), "Demo transfer to Demo Customer", new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), 50.00m, null, null, false, "TXN-20260825-DEMO-REVERSE", null, null, null, new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), "Completed", new Guid("30000000-0000-0000-0000-000000000002"), 50.00m, "USD", "Transfer" },
                    { new Guid("4a6e449e-6397-45f6-a446-5936e882c406"), new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), null, 50.00m, new DateTime(2026, 8, 25, 12, 5, 0, 0, DateTimeKind.Utc), "Transfer from BA-000002-CHECKING", new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), 50.00m, null, null, false, "TXN-20260825-DEMO-REVERSE", null, null, null, new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7222"), "Completed", new Guid("30000000-0000-0000-0000-000000000002"), 50.00m, "USD", "Transfer" }
                });

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("9a99a021-b892-4f5a-bd98-36a5afbf0c79"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.IEPsjW7/seW/Hod2eRay9Q5CVGlxWhtZKNtQA8plknc=");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("dd72f286-0cf8-44ad-81ea-d85c5964d29d"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.ERITFBUWFxgZGhscHR4fIA==.223VFhbyCUiSO0B8hcUwQp3262ssfZK3V4DOMgE+K6M=");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.ISIjJCUmJygpKissLS4vMA==.bmERb4hBB62LAbgdGANDKTOu9vy2bauv5BkdQ9/H5RU=");

            migrationBuilder.InsertData(
                table: "BankCards",
                columns: new[] { "Id", "AccountId", "Brand", "CardNumber", "CardholderName", "CreatedAtUtc", "Cvv", "ExpiryDate", "Status" },
                values: new object[] { new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5898"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7233"), "Mastercard", "5425233430109911", "Yamilet Recipient", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "519", new DateTime(2030, 11, 24, 0, 0, 0, 0, DateTimeKind.Utc), "Active" });

            migrationBuilder.InsertData(
                table: "Transactions",
                columns: new[] { "Id", "AccountId", "AdminNote", "Amount", "CreatedAtUtc", "Description", "DestinationAccountId", "DestinationAmount", "DocumentsRequestNote", "DocumentsRequestedAtUtc", "IsHighRiskReview", "ReferenceNumber", "ReviewReason", "ReviewedAtUtc", "ReviewedByUserId", "SourceAccountId", "Status", "TransactionCategoryId", "TransferAmount", "TransferCurrency", "Type" },
                values: new object[] { new Guid("4a6e449e-6397-45f6-a446-5936e882c404"), new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7233"), null, 5000.00m, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Initial recipient savings deposit", null, null, null, null, false, "TXN-20260101-0004", null, null, null, null, "Completed", null, null, null, "Transfer" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5898"));

            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c403"));

            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c404"));

            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c405"));

            migrationBuilder.DeleteData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c406"));

            migrationBuilder.DeleteData(
                table: "Accounts",
                keyColumn: "Id",
                keyValue: new Guid("deed75d2-e898-4c2d-a7e3-2fa1152d7233"));

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

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("9a99a021-b892-4f5a-bd98-36a5afbf0c79"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("dd72f286-0cf8-44ad-81ea-d85c5964d29d"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.ERITFBUWFxgZGhscHR4fIA==.3+i0Vv41HWR1ofVLRyJthACrUOkA/W2oSnAkMKm57ak=");

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49"),
                column: "PasswordHash",
                value: "PBKDF2-SHA256.100000.AQIDBAUGBwgJCgsMDQ4PEA==.1n/kUWC8lKsVwbzvVqx46PhnAJHTK4Pvs6t0RwMyEOQ=");
        }
    }
}
