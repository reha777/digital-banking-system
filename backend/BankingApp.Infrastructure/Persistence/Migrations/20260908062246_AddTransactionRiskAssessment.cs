using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddTransactionRiskAssessment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "RiskModelVersion",
                table: "Transactions",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RiskProbability",
                table: "Transactions",
                type: "decimal(9,8)",
                precision: 9,
                scale: 8,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c401"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_SourceAccountId_CreatedAtUtc",
                table: "Transactions",
                columns: new[] { "SourceAccountId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_SourceAccountId_DestinationAccountId_Status",
                table: "Transactions",
                columns: new[] { "SourceAccountId", "DestinationAccountId", "Status" });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c402"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c403"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c404"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c405"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("4a6e449e-6397-45f6-a446-5936e882c406"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("fd261404-8751-4faa-bffa-cdf7ea592903"),
                columns: new[] { "RiskModelVersion", "RiskProbability" },
                values: new object[] { null, null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Transactions_SourceAccountId_CreatedAtUtc",
                table: "Transactions");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_SourceAccountId_DestinationAccountId_Status",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "RiskModelVersion",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "RiskProbability",
                table: "Transactions");
        }
    }
}
