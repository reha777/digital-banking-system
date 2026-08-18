namespace BankingApp.Application.Transactions
{
    public class MoneyTransferQuoteResponse
    {
        public string SourceCurrency { get; set; } = string.Empty;
        public string TransferCurrency { get; set; } = string.Empty;
        public string DestinationCurrency { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public decimal ExchangeRate { get; set; }
        public decimal DebitAmount { get; set; }
        public decimal DestinationAmount { get; set; }
        public bool RequiresConversion { get; set; }
    }
}
