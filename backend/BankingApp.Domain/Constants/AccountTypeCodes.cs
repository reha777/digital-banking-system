namespace BankingApp.Domain.Constants;

public static class AccountTypeCodes
{
    public const string Checking = "CHECKING";
    public const string Savings = "SAVINGS";
    public static readonly Guid CheckingId = Guid.Parse("9e7f4a43-cc89-4a41-847a-100000000001");
    public static readonly Guid SavingsId = Guid.Parse("9e7f4a43-cc89-4a41-847a-100000000002");
}
