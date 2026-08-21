namespace BankingApp.Application.Loans;

public class LoanQuoteRequest
{
    public Guid LoanProductId { get; set; }
    public decimal Principal { get; set; }
    public int TermMonths { get; set; }
}
