namespace BankingApp.Domain.Entities;

public class LoanProduct
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
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public ICollection<LoanApplication> Applications { get; set; } = new List<LoanApplication>();
}
