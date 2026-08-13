using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BankingApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AdminUserPreferences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ThemeMode = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    SidebarStyle = table.Column<string>(type: "nvarchar(12)", maxLength: 12, nullable: false),
                    DateFormat = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    TimeFormat = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    FirstDayOfWeek = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    NumberFormat = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    DefaultItemsPerPage = table.Column<int>(type: "int", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminUserPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdminUserPreferences_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SystemSettings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SystemName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    SystemShortName = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CompanyName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    CompanyEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    CompanyPhone = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Timezone = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    SessionTimeoutMinutes = table.Column<int>(type: "int", nullable: false),
                    AutoLogoutWarningMinutes = table.Column<int>(type: "int", nullable: false),
                    EnableDataCaching = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SystemSettings", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AdminUserPreferences_UserId",
                table: "AdminUserPreferences",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdminUserPreferences");

            migrationBuilder.DropTable(
                name: "SystemSettings");
        }
    }
}
