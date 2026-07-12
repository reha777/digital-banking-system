using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHighRiskTransactionReviews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AdminNote",
                table: "Transactions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DocumentsRequestNote",
                table: "Transactions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DocumentsRequestedAtUtc",
                table: "Transactions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsHighRiskReview",
                table: "Transactions",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "ReviewReason",
                table: "Transactions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ReviewedAtUtc",
                table: "Transactions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ReviewedByUserId",
                table: "Transactions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TransactionDocuments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TransactionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(180)", maxLength: 180, nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    Content = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                    UploadedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TransactionDocuments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TransactionDocuments_Transactions_TransactionId",
                        column: x => x.TransactionId,
                        principalTable: "Transactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                columns: new[] { "AdminNote", "DocumentsRequestNote", "DocumentsRequestedAtUtc", "IsHighRiskReview", "ReviewReason", "ReviewedAtUtc", "ReviewedByUserId" },
                values: new object[] { null, null, null, false, null, null, null });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("fd261404-8751-4faa-bffa-cdf7ea592903"),
                columns: new[] { "AdminNote", "DocumentsRequestNote", "DocumentsRequestedAtUtc", "IsHighRiskReview", "ReviewReason", "ReviewedAtUtc", "ReviewedByUserId" },
                values: new object[] { null, null, null, false, null, null, null });

            migrationBuilder.CreateIndex(
                name: "IX_TransactionDocuments_TransactionId",
                table: "TransactionDocuments",
                column: "TransactionId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TransactionDocuments");

            migrationBuilder.DropColumn(
                name: "AdminNote",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "DocumentsRequestNote",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "DocumentsRequestedAtUtc",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "IsHighRiskReview",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ReviewReason",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ReviewedAtUtc",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ReviewedByUserId",
                table: "Transactions");
        }
    }
}
