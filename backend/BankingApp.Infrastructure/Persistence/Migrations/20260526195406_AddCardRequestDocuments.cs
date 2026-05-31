using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCardRequestDocuments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DocumentsRequestNote",
                table: "CardRequests",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DocumentsRequestedAtUtc",
                table: "CardRequests",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CardRequestDocuments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CardRequestId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(180)", maxLength: 180, nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    Content = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                    UploadedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CardRequestDocuments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CardRequestDocuments_CardRequests_CardRequestId",
                        column: x => x.CardRequestId,
                        principalTable: "CardRequests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CardRequestDocuments_CardRequestId",
                table: "CardRequestDocuments",
                column: "CardRequestId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CardRequestDocuments");

            migrationBuilder.DropColumn(
                name: "DocumentsRequestNote",
                table: "CardRequests");

            migrationBuilder.DropColumn(
                name: "DocumentsRequestedAtUtc",
                table: "CardRequests");
        }
    }
}
