namespace BankingApp.Application.Loans;

public class LoanApplicationCreateRequest
{
    public Guid LoanProductId { get; set; }
    public Guid DestinationAccountId { get; set; }
    public decimal Principal { get; set; }
    public int TermMonths { get; set; }
    public Guid ClientRequestId { get; set; }
}
