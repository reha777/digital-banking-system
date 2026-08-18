namespace BankingApp.Application.Cards
{
    public class CardSensitiveDataResponse
    {
        public Guid Id { get; set; }
        public string CardNumber { get; set; } = string.Empty;
        public string Cvv { get; set; } = string.Empty;
    }
}
