using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerProfilePhoto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "ProfilePhoto",
                table: "Users",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProfilePhotoContentType",
                table: "Users",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProfilePhotoUpdatedAtUtc",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("9a99a021-b892-4f5a-bd98-36a5afbf0c79"),
                columns: new[] { "ProfilePhoto", "ProfilePhotoContentType", "ProfilePhotoUpdatedAtUtc" },
                values: new object[] { null, null, null });

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("dd72f286-0cf8-44ad-81ea-d85c5964d29d"),
                columns: new[] { "ProfilePhoto", "ProfilePhotoContentType", "ProfilePhotoUpdatedAtUtc" },
                values: new object[] { null, null, null });

            migrationBuilder.UpdateData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("f5573a40-f822-45c4-a841-b6ab5d5a0c49"),
                columns: new[] { "ProfilePhoto", "ProfilePhotoContentType", "ProfilePhotoUpdatedAtUtc" },
                values: new object[] { null, null, null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ProfilePhoto",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ProfilePhotoContentType",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ProfilePhotoUpdatedAtUtc",
                table: "Users");
        }
    }
}
