using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddTransactionCurrencyConversion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DestinationAmount",
                table: "Transactions",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "TransferAmount",
                table: "Transactions",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TransferCurrency",
                table: "Transactions",
                type: "nvarchar(3)",
                maxLength: 3,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                columns: new[] { "DestinationAmount", "TransferAmount", "TransferCurrency" },
                values: new object[] { null, null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("fd261404-8751-4faa-bffa-cdf7ea592903"),
                columns: new[] { "DestinationAmount", "TransferAmount", "TransferCurrency" },
                values: new object[] { null, null, null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DestinationAmount",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "TransferAmount",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "TransferCurrency",
                table: "Transactions");
        }
    }
}
