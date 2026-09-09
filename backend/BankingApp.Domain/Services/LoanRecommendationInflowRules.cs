using System.Linq.Expressions;
using BankingApp.Domain.Entities;
using BankingApp.Domain.Enums;

namespace BankingApp.Domain.Services;

/// <summary>
/// Defines which transactions count as real incoming money for the loan
/// recommender's inflow signal.
///
/// A positive ledger amount is not by itself income. Moving money between one's own
/// accounts writes a positive credit leg, and so does a loan disbursement, but
/// neither is new money: counting them lets a customer inflate their own
/// recommendation score, and in the disbursement case creates a feedback loop where
/// borrowing makes the recommender offer more borrowing.
///
/// This is intentionally separate from
/// <see cref="BusinessTransactionVolume"/>: reported transfer volume and customer
/// income are different questions, even though both reason about the same
/// debit/credit shapes.
///
/// Qualifying inflow = a Completed credit leg of a <see cref="TransactionType.Transfer"/>
/// whose counterparty is somebody else.
///
/// Excluded, and why:
/// <list type="bullet">
/// <item><see cref="TransactionType.InternalTransfer"/> — the customer's own money,
/// net worth unchanged.</item>
/// <item>A <see cref="TransactionType.Transfer"/> whose source account belongs to the
/// same customer — same reason, caught by ownership rather than by type alone.</item>
/// <item><see cref="TransactionType.LoanDisbursement"/> — borrowed money, not income.</item>
/// <item><see cref="TransactionType.LoanRepayment"/> — an outgoing debit.</item>
/// <item><see cref="TransactionType.TopUp"/> — self-service funding the customer
/// triggers themselves, with no counterparty in the system to corroborate it. The
/// recommender has always excluded Top Up from its signals; treating it as income
/// would reopen the same self-inflation problem this rule closes.</item>
/// <item>Anything not Completed, and anything outside the scoring window.</item>
/// </list>
/// </summary>
public static class LoanRecommendationInflowRules
{
    /// <summary>
    /// The credit legs that may qualify, before the counterparty is known. Whitelists
    /// the transaction type rather than trusting the sign of the amount.
    /// </summary>
    public static Expression<Func<Transaction, bool>> QualifyingCreditLeg =>
        transaction =>
            transaction.Status == TransactionStatus.Completed &&
            transaction.Amount > 0 &&
            transaction.Type == TransactionType.Transfer;

    /// <summary>
    /// Keeps only credits that came from somebody else. A transfer whose source is one
    /// of <paramref name="ownAccountIds"/> is the customer's own money moving around.
    /// A credit with no recorded source account cannot be a self-transfer, so it stays.
    /// </summary>
    public static Expression<Func<Transaction, bool>> FromExternalCounterparty(
        IReadOnlyCollection<Guid> ownAccountIds) =>
        transaction =>
            transaction.SourceAccountId == null ||
            !ownAccountIds.Contains(transaction.SourceAccountId.Value);
}
