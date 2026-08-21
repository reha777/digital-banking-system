namespace BankingApp.Application.Loans;

public class LoanProductResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public decimal MinPrincipal { get; set; }
    public decimal MaxPrincipal { get; set; }
    public decimal AnnualInterestRate { get; set; }
    public int MinTermMonths { get; set; }
    public int MaxTermMonths { get; set; }
    public int TermStepMonths { get; set; }
}
