using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddReferenceDataCatalog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "TransactionCategoryId",
                table: "Transactions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DocumentTypeId",
                table: "TransactionDocuments",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LoanPurposeId",
                table: "LoanApplications",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DocumentTypeId",
                table: "CardRequestDocuments",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ReferenceDataItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Code = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReferenceDataItems", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "ReferenceDataItems",
                columns: new[] { "Id", "Code", "CreatedAtUtc", "Description", "IsActive", "Name", "SortOrder", "Type", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { new Guid("10000000-0000-0000-0000-000000000001"), "GENERAL", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "General purpose", 10, "loan-purposes", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("10000000-0000-0000-0000-000000000002"), "HOME", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Home improvement", 20, "loan-purposes", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("10000000-0000-0000-0000-000000000003"), "EDUCATION", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Education", 30, "loan-purposes", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("20000000-0000-0000-0000-000000000001"), "IDENTITY", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Identity document", 10, "document-types", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("20000000-0000-0000-0000-000000000002"), "PROOF_OF_INCOME", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Proof of income", 20, "document-types", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("20000000-0000-0000-0000-000000000003"), "BANK_STATEMENT", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Bank statement", 30, "document-types", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("30000000-0000-0000-0000-000000000001"), "GENERAL", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "General", 10, "transaction-categories", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("30000000-0000-0000-0000-000000000002"), "TRANSFER", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Transfer", 20, "transaction-categories", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("30000000-0000-0000-0000-000000000003"), "LOAN", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Loan", 30, "transaction-categories", new DateTime(2026, 8, 24, 0, 0, 0, 0, DateTimeKind.Utc) }
                });

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("b8e0dbf7-536f-4301-99c7-5b3a1e03f450"),
                column: "TransactionCategoryId",
                value: null);

            migrationBuilder.UpdateData(
                table: "Transactions",
                keyColumn: "Id",
                keyValue: new Guid("fd261404-8751-4faa-bffa-cdf7ea592903"),
                column: "TransactionCategoryId",
                value: null);

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_TransactionCategoryId",
                table: "Transactions",
                column: "TransactionCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_TransactionDocuments_DocumentTypeId",
                table: "TransactionDocuments",
                column: "DocumentTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_LoanApplications_LoanPurposeId",
                table: "LoanApplications",
                column: "LoanPurposeId");

            migrationBuilder.CreateIndex(
                name: "IX_CardRequestDocuments_DocumentTypeId",
                table: "CardRequestDocuments",
                column: "DocumentTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_ReferenceDataItems_Type_Code",
                table: "ReferenceDataItems",
                columns: new[] { "Type", "Code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReferenceDataItems_Type_IsActive_SortOrder",
                table: "ReferenceDataItems",
                columns: new[] { "Type", "IsActive", "SortOrder" });

            migrationBuilder.AddForeignKey(
                name: "FK_CardRequestDocuments_ReferenceDataItems_DocumentTypeId",
                table: "CardRequestDocuments",
                column: "DocumentTypeId",
                principalTable: "ReferenceDataItems",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_LoanApplications_ReferenceDataItems_LoanPurposeId",
                table: "LoanApplications",
                column: "LoanPurposeId",
                principalTable: "ReferenceDataItems",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_TransactionDocuments_ReferenceDataItems_DocumentTypeId",
                table: "TransactionDocuments",
                column: "DocumentTypeId",
                principalTable: "ReferenceDataItems",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Transactions_ReferenceDataItems_TransactionCategoryId",
                table: "Transactions",
                column: "TransactionCategoryId",
                principalTable: "ReferenceDataItems",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CardRequestDocuments_ReferenceDataItems_DocumentTypeId",
                table: "CardRequestDocuments");

            migrationBuilder.DropForeignKey(
                name: "FK_LoanApplications_ReferenceDataItems_LoanPurposeId",
                table: "LoanApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_TransactionDocuments_ReferenceDataItems_DocumentTypeId",
                table: "TransactionDocuments");

            migrationBuilder.DropForeignKey(
                name: "FK_Transactions_ReferenceDataItems_TransactionCategoryId",
                table: "Transactions");

            migrationBuilder.DropTable(
                name: "ReferenceDataItems");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_TransactionCategoryId",
                table: "Transactions");

            migrationBuilder.DropIndex(
                name: "IX_TransactionDocuments_DocumentTypeId",
                table: "TransactionDocuments");

            migrationBuilder.DropIndex(
                name: "IX_LoanApplications_LoanPurposeId",
                table: "LoanApplications");

            migrationBuilder.DropIndex(
                name: "IX_CardRequestDocuments_DocumentTypeId",
                table: "CardRequestDocuments");

            migrationBuilder.DropColumn(
                name: "TransactionCategoryId",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "DocumentTypeId",
                table: "TransactionDocuments");

            migrationBuilder.DropColumn(
                name: "LoanPurposeId",
                table: "LoanApplications");

            migrationBuilder.DropColumn(
                name: "DocumentTypeId",
                table: "CardRequestDocuments");
        }
    }
}
