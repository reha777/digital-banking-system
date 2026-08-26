namespace BankingApp.Domain.Enums;

public enum NotificationType
{
    CardRequestApproved = 1, CardRequestRejected, CardDocumentsRequested,
    TransactionApproved, TransactionRejected, TransactionDocumentsRequested,
    LoanApproved, LoanRejected, LoanPaymentOverdue,
    NewCardRequest, CardDocumentsUploaded, NewHighRiskTransaction,
    TransactionDocumentsUploaded, NewLoanApplication
}
