using System.ComponentModel.DataAnnotations;

namespace BankingApp.Application.Customers
{
    public class CustomerUpdateRequest
    {
        [Required]
        [MaxLength(100)]
        public string FirstName { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string LastName { get; set; } = string.Empty;

        [Required]
        [Phone]
        [MaxLength(30)]
        public string PhoneNumber { get; set; } = string.Empty;
    }
}
