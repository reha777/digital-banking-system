using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceAccountTypeEnumWithReferenceData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "AccountTypeId",
                table: "Accounts",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AccountTypeDefinitions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false, collation: "Latin1_General_100_CI_AS"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccountTypeDefinitions", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "AccountTypeDefinitions",
                columns: new[] { "Id", "Code", "CreatedAtUtc", "IsActive", "Name", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { new Guid("9e7f4a43-cc89-4a41-847a-100000000001"), "CHECKING", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, "Checking", null },
                    { new Guid("9e7f4a43-cc89-4a41-847a-100000000002"), "SAVINGS", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, "Savings", null }
                });

            migrationBuilder.Sql("""
                UPDATE [Accounts] SET [AccountTypeId] = CASE [AccountType]
                    WHEN N'Checking' THEN '9e7f4a43-cc89-4a41-847a-100000000001'
                    WHEN N'Savings' THEN '9e7f4a43-cc89-4a41-847a-100000000002'
                    ELSE NULL END;
                IF EXISTS (SELECT 1 FROM [Accounts] WHERE [AccountTypeId] IS NULL)
                    THROW 51000, 'Account type migration found an unmapped account.', 1;
                """);
            migrationBuilder.AlterColumn<Guid>(name: "AccountTypeId", table: "Accounts", type: "uniqueidentifier",
                nullable: false, oldClrType: typeof(Guid), oldType: "uniqueidentifier", oldNullable: true);
            migrationBuilder.DropColumn(name: "AccountType", table: "Accounts");

            migrationBuilder.CreateIndex(
                name: "IX_Accounts_AccountTypeId",
                table: "Accounts",
                column: "AccountTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_AccountTypeDefinitions_Code",
                table: "AccountTypeDefinitions",
                column: "Code",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Accounts_AccountTypeDefinitions_AccountTypeId",
                table: "Accounts",
                column: "AccountTypeId",
                principalTable: "AccountTypeDefinitions",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Accounts_AccountTypeDefinitions_AccountTypeId",
                table: "Accounts");
            migrationBuilder.DropIndex(
                name: "IX_Accounts_AccountTypeId",
                table: "Accounts");
            migrationBuilder.AddColumn<string>(
                name: "AccountType",
                table: "Accounts",
                type: "nvarchar(25)",
                maxLength: 25,
                nullable: true);
            migrationBuilder.Sql("""
                UPDATE a SET [AccountType] = CASE t.[Code]
                    WHEN N'SAVINGS' THEN N'Savings' ELSE N'Checking' END
                FROM [Accounts] a INNER JOIN [AccountTypeDefinitions] t ON a.[AccountTypeId] = t.[Id];
                """);
            migrationBuilder.AlterColumn<string>(name: "AccountType", table: "Accounts", type: "nvarchar(25)",
                maxLength: 25, nullable: false, oldClrType: typeof(string), oldType: "nvarchar(25)", oldMaxLength: 25, oldNullable: true);
            migrationBuilder.DropColumn(name: "AccountTypeId", table: "Accounts");
            migrationBuilder.DropTable(name: "AccountTypeDefinitions");
        }
    }
}
