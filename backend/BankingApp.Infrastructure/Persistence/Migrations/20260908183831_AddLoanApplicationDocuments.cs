using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLoanApplicationDocuments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LoanApplications_UserId",
                table: "LoanApplications");

            migrationBuilder.AddColumn<string>(
                name: "DocumentRequestDescription",
                table: "LoanApplications",
                type: "nvarchar(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DocumentRequestMessage",
                table: "LoanApplications",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DocumentRequestedAtUtc",
                table: "LoanApplications",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "LoanDocuments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LoanApplicationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UploadedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(180)", maxLength: 180, nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    Content = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                    UploadedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LoanDocuments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LoanDocuments_LoanApplications_LoanApplicationId",
                        column: x => x.LoanApplicationId,
                        principalTable: "LoanApplications",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LoanDocuments_Users_UploadedByUserId",
                        column: x => x.UploadedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LoanApplications_UserId",
                table: "LoanApplications",
                column: "UserId",
                unique: true,
                filter: "[Status] IN (N'Pending', N'DocumentsRequested')");

            migrationBuilder.CreateIndex(
                name: "IX_LoanDocuments_LoanApplicationId_UploadedAtUtc",
                table: "LoanDocuments",
                columns: new[] { "LoanApplicationId", "UploadedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_LoanDocuments_UploadedByUserId",
                table: "LoanDocuments",
                column: "UploadedByUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LoanDocuments");

            migrationBuilder.DropIndex(
                name: "IX_LoanApplications_UserId",
                table: "LoanApplications");

            migrationBuilder.DropColumn(
                name: "DocumentRequestDescription",
                table: "LoanApplications");

            migrationBuilder.DropColumn(
                name: "DocumentRequestMessage",
                table: "LoanApplications");

            migrationBuilder.DropColumn(
                name: "DocumentRequestedAtUtc",
                table: "LoanApplications");

            migrationBuilder.CreateIndex(
                name: "IX_LoanApplications_UserId",
                table: "LoanApplications",
                column: "UserId",
                unique: true,
                filter: "[Status] = N'Pending'");
        }
    }
}
