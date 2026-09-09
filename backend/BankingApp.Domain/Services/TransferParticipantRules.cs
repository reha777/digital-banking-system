using System.Linq.Expressions;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Services;

/// <summary>
/// The single definition of "may this account and its owner take part in a transfer".
///
/// Transfer creation and admin approval share it so the two cannot drift: an
/// approval decision must be based on the current state of the system, not on the
/// state that happened to be valid when the request was submitted.
/// </summary>
public static class TransferParticipantRules
{
    /// <summary>
    /// Query-side form, translatable by EF. Requires <c>Account.User</c> to be joinable.
    /// </summary>
    public static Expression<Func<Account, bool>> ActiveParticipant =>
        account =>
            account.Status == AccountStatus.Active &&
            !account.User.IsDeleted &&
            account.User.Status == CustomerStatus.Active;

    /// <summary>In-memory form, for revalidating an already loaded entity.</summary>
    public static bool AccountCanParticipate(Account account) =>
        account.Status == AccountStatus.Active;

    /// <summary>In-memory form, for revalidating an already loaded owner.</summary>
    public static bool CustomerCanParticipate(User user) =>
        !user.IsDeleted && user.Status == CustomerStatus.Active;
}
