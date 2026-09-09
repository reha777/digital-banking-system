namespace BankingApp.Application.Cards
{
    /// <summary>
    /// One-time result of issuing a card. This is the only place a CVV is ever
    /// returned: it is generated during issuance, never persisted, and cannot be
    /// retrieved again by any endpoint afterwards.
    /// </summary>
    public class CardIssueResult
    {
        public Guid CardId { get; set; }

        public string CardNumber { get; set; } = string.Empty;

        public int ExpiryMonth { get; set; }

        public int ExpiryYear { get; set; }

        /// <summary>
        /// Shown once. Not stored in the database, audit log, notifications or logs.
        /// </summary>
        public string OneTimeCvv { get; set; } = string.Empty;

        public string Warning { get; set; } =
            "CVV is shown only once and cannot be retrieved later.";
    }
}
