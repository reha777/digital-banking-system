using BankingApp.Domain.Enums;

namespace BankingApp.Application.Customers
{
    public class CustomerStatusUpdateRequest
    {
        public CustomerStatus Status { get; set; }
    }
}
