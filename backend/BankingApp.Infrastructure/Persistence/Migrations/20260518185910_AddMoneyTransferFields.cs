using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMoneyTransferFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Transactions_ReferenceNumber",
                table: "Transactions");

            migrationBuilder.AddColumn<Guid>(
                name: "DestinationAccountId",
                table: "Transactions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SourceAccountId",
                table: "Transactions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                columns: new[] { "DestinationAccountId", "SourceAccountId" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("fd261404-8751-4faa-bffa-cdf7ea592903"),
                columns: new[] { "DestinationAccountId", "SourceAccountId" },
                values: new object[] { null, null });

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_ReferenceNumber",
                table: "Transactions",
                column: "ReferenceNumber");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Transactions_ReferenceNumber",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "DestinationAccountId",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "SourceAccountId",
                table: "Transactions");

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_ReferenceNumber",
                table: "Transactions",
                column: "ReferenceNumber",
                unique: true);
        }
    }
}
