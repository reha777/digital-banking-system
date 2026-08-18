namespace BankingApp.Application.Auth
{
    public class UserResponse
    {
        public Guid Id { get; set; }

        public string FirstName { get; set; } = string.Empty;

        public string LastName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string PhoneNumber { get; set; } = string.Empty;

        public string Role { get; set; } = string.Empty;

        public bool HasProfilePhoto { get; set; }

        public DateTime? ProfilePhotoUpdatedAtUtc { get; set; }
    }
}
