using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Transactions;

public class InternalTransferQuoteRequest
{
    [Required]
    public Guid SourceAccountId { get; set; }

    [Required]
    public Guid DestinationAccountId { get; set; }

    public decimal Amount { get; set; }
}

public class InternalTransferRequest : InternalTransferQuoteRequest
{
    [MaxLength(250)]
    public string? Description { get; set; }
}
