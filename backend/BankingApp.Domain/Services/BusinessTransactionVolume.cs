using System.Linq.Expressions;
using BankingApp.Domain.Entities;

namespace BankingApp.Domain.Services;

/// <summary>
/// The single definition of business transaction volume, shared by the admin
/// dashboard and the PDF report so the two cannot drift apart.
///
/// A standard transfer is stored as two ledger rows with the same
/// <see cref="Transaction.ReferenceNumber"/>: a debit on the source account and a
/// credit on the destination account. Summing both sides reports one business
/// transfer of 100 as a volume of 200, so exactly one row per business event is
/// counted — the canonical row.
///
/// The canonical row is the debit side (<c>AccountId == SourceAccountId</c>), or the
/// row itself when there is no source account (Top Up and loan disbursement are
/// credit-only, single-row business events). This is the same rule the admin
/// transaction list already applies, it needs no grouping, it is EF-translatable,
/// and it is naturally robust: rows with no reference number stay separate business
/// events, and an orphaned or duplicated side is still counted at most once.
/// </summary>
public static class BusinessTransactionVolume
{
    /// <summary>
    /// Selects the single canonical ledger row of each business transaction.
    /// </summary>
    public static Expression<Func<Transaction, bool>> CanonicalRow =>
        transaction =>
            !transaction.SourceAccountId.HasValue ||
            transaction.AccountId == transaction.SourceAccountId.Value;

    /// <summary>In-memory counterpart of <see cref="CanonicalRow"/>.</summary>
    public static bool IsCanonicalRow(Guid accountId, Guid? sourceAccountId) =>
        !sourceAccountId.HasValue || accountId == sourceAccountId.Value;

    /// <summary>
    /// The business amount a canonical row contributes. <c>TransferAmount</c> is the
    /// amount the customer actually requested, so it is preferred; ledger-only rows
    /// that never carried one fall back to the posted amount.
    /// </summary>
    public static decimal AmountOf(decimal amount, decimal? transferAmount) =>
        Math.Abs(transferAmount ?? amount);

    /// <summary>
    /// The currency the business amount belongs to. A cross-currency transfer is
    /// attributed once, to the currency the customer transferred in, rather than
    /// having its debit and credit legs added together as if they were the same unit.
    /// </summary>
    public static string CurrencyOf(string? transferCurrency, string accountCurrency) =>
        string.IsNullOrWhiteSpace(transferCurrency) ? accountCurrency : transferCurrency;
}
