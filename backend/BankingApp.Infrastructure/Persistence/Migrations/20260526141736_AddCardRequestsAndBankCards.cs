using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCardRequestsAndBankCards : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BankCards",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CardNumber = table.Column<string>(type: "nvarchar(19)", maxLength: 19, nullable: false),
                    CardholderName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Cvv = table.Column<string>(type: "nvarchar(4)", maxLength: 4, nullable: false),
                    ExpiryDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Brand = table.Column<string>(type: "nvarchar(25)", maxLength: 25, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(25)", maxLength: 25, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BankCards", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BankCards_Accounts_AccountId",
                        column: x => x.AccountId,
                        principalTable: "Accounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "CardRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CardholderName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Currency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    DocumentNumber = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    DeliveryAddress = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: false),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(25)", maxLength: 25, nullable: false),
                    AdminNote = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ApprovedAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ApprovedCardId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReviewedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ReviewedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CardRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CardRequests_Accounts_ApprovedAccountId",
                        column: x => x.ApprovedAccountId,
                        principalTable: "Accounts",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_CardRequests_BankCards_ApprovedCardId",
                        column: x => x.ApprovedCardId,
                        principalTable: "BankCards",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_CardRequests_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "BankCards",
                columns: new[] { "Id", "AccountId", "Brand", "CardNumber", "CardholderName", "CreatedAtUtc", "Cvv", "ExpiryDate", "Status" },
                values: new object[] { new Guid("a8f0f3aa-e7d3-460c-86ff-6cfe0f5105dd"), new Guid("dbdd0766-a83e-4a7d-944c-af7d0373ff50"), "Mastercard", "4562112245957852", "Demo Customer", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "6986", new DateTime(2030, 6, 24, 0, 0, 0, 0, DateTimeKind.Utc), "Active" });

            migrationBuilder.CreateIndex(
                name: "IX_BankCards_AccountId",
                table: "BankCards",
                column: "AccountId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_BankCards_CardNumber",
                table: "BankCards",
                column: "CardNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CardRequests_ApprovedAccountId",
                table: "CardRequests",
                column: "ApprovedAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_CardRequests_ApprovedCardId",
                table: "CardRequests",
                column: "ApprovedCardId");

            migrationBuilder.CreateIndex(
                name: "IX_CardRequests_UserId",
                table: "CardRequests",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CardRequests");

            migrationBuilder.DropTable(
                name: "BankCards");
        }
    }
}
