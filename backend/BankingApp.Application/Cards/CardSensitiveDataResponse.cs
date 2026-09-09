namespace BankingApp.Application.Cards
{
    /// <summary>
    /// Sensitive card data the owner may re-read on demand. The CVV is
    /// deliberately absent: it is not persisted and is only ever returned once,
    /// in <see cref="CardIssueResult"/>, at issuance time.
    /// </summary>
    public class CardSensitiveDataResponse
    {
        public Guid Id { get; set; }
        public string CardNumber { get; set; } = string.Empty;
        public DateTime ExpiryDate { get; set; }
    }
}
