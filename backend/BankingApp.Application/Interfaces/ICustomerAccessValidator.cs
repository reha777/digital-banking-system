namespace BankingApp.Application.Interfaces;

public interface ICustomerAccessValidator
{
    Task<bool> IsActiveCustomerAsync(
        Guid userId,
        CancellationToken cancellationToken = default);
}
