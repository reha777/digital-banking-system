using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemovePersistedCardCvv : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Cvv",
                table: "BankCards");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Cvv",
                table: "BankCards",
                type: "nvarchar(4)",
                maxLength: 4,
                nullable: false,
                defaultValue: "");

            migrationBuilder.UpdateData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5897"),
                column: "Cvv",
                value: "417");

            migrationBuilder.UpdateData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("62f3cd21-d263-40ca-ae58-07d13f7c5898"),
                column: "Cvv",
                value: "519");

            migrationBuilder.UpdateData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("741fc77c-fec7-4b53-92df-d664d14935e8"),
                column: "Cvv",
                value: "315");

            migrationBuilder.UpdateData(
                table: "BankCards",
                keyColumn: "Id",
                keyValue: new Guid("a8f0f3aa-e7d3-460c-86ff-6cfe0f5105dd"),
                column: "Cvv",
                value: "6986");
        }
    }
}
