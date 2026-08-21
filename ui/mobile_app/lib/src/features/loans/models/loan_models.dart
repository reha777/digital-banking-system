enum LoanApplicationStatus { pending, approved, rejected }

double _number(Map<String, dynamic> json, String key) =>
    (json[key] as num? ?? 0).toDouble();

class LoanProductModel {
  const LoanProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.minPrincipal,
    required this.maxPrincipal,
    required this.annualInterestRate,
    required this.minTermMonths,
    required this.maxTermMonths,
    required this.termStepMonths,
  });
  factory LoanProductModel.fromJson(Map<String, dynamic> json) =>
      LoanProductModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        currency: json['currency']?.toString() ?? '',
        minPrincipal: _number(json, 'minPrincipal'),
        maxPrincipal: _number(json, 'maxPrincipal'),
        annualInterestRate: _number(json, 'annualInterestRate'),
        minTermMonths: (json['minTermMonths'] as num? ?? 0).toInt(),
        maxTermMonths: (json['maxTermMonths'] as num? ?? 0).toInt(),
        termStepMonths: (json['termStepMonths'] as num? ?? 1).toInt(),
      );
  final String id, name, description, currency;
  final double minPrincipal, maxPrincipal, annualInterestRate;
  final int minTermMonths, maxTermMonths, termStepMonths;
  List<int> get termOptions => [
    for (
      var value = minTermMonths;
      value <= maxTermMonths;
      value += termStepMonths
    )
      value,
  ];
}

class LoanScheduleItemModel {
  const LoanScheduleItemModel({
    required this.paymentNumber,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
  });
  factory LoanScheduleItemModel.fromJson(Map<String, dynamic> json) =>
      LoanScheduleItemModel(
        paymentNumber: (json['paymentNumber'] as num? ?? 0).toInt(),
        dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
        principal: _number(json, 'principal'),
        interest: _number(json, 'interest'),
        total: _number(json, 'total'),
      );
  final int paymentNumber;
  final DateTime? dueDate;
  final double principal, interest, total;
}

class LoanQuoteModel {
  const LoanQuoteModel({
    required this.productId,
    required this.productName,
    required this.currency,
    required this.principal,
    required this.annualInterestRate,
    required this.termMonths,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalRepayment,
    required this.schedule,
  });
  factory LoanQuoteModel.fromJson(Map<String, dynamic> json) => LoanQuoteModel(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? '',
    currency: json['currency']?.toString() ?? '',
    principal: _number(json, 'principal'),
    annualInterestRate: _number(json, 'annualInterestRate'),
    termMonths: (json['termMonths'] as num? ?? 0).toInt(),
    monthlyPayment: _number(json, 'monthlyPayment'),
    totalInterest: _number(json, 'totalInterest'),
    totalRepayment: _number(json, 'totalRepayment'),
    schedule: (json['schedule'] as List? ?? [])
        .map((e) => LoanScheduleItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  final String productId, productName, currency;
  final double principal,
      annualInterestRate,
      monthlyPayment,
      totalInterest,
      totalRepayment;
  final int termMonths;
  final List<LoanScheduleItemModel> schedule;
}

class LoanApplicationModel {
  const LoanApplicationModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.destinationAccountId,
    required this.destinationAccountNumber,
    required this.principal,
    required this.currency,
    required this.annualInterestRate,
    required this.termMonths,
    required this.estimatedMonthlyPayment,
    required this.estimatedTotalInterest,
    required this.estimatedTotalRepayment,
    required this.status,
    required this.submittedAtUtc,
    this.reviewedAtUtc,
    this.adminNote,
  });
  factory LoanApplicationModel.fromJson(Map<String, dynamic> json) =>
      LoanApplicationModel(
        id: json['id']?.toString() ?? '',
        productId: json['productId']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        destinationAccountId: json['destinationAccountId']?.toString() ?? '',
        destinationAccountNumber:
            json['destinationAccountNumber']?.toString() ?? '',
        principal: _number(json, 'principal'),
        currency: json['currency']?.toString() ?? '',
        annualInterestRate: _number(json, 'annualInterestRate'),
        termMonths: (json['termMonths'] as num? ?? 0).toInt(),
        estimatedMonthlyPayment: _number(json, 'estimatedMonthlyPayment'),
        estimatedTotalInterest: _number(json, 'estimatedTotalInterest'),
        estimatedTotalRepayment: _number(json, 'estimatedTotalRepayment'),
        status: _status(json['status']),
        submittedAtUtc:
            DateTime.tryParse(json['submittedAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        reviewedAtUtc: DateTime.tryParse(
          json['reviewedAtUtc']?.toString() ?? '',
        ),
        adminNote: json['adminNote']?.toString(),
      );
  final String id,
      productId,
      productName,
      destinationAccountId,
      destinationAccountNumber,
      currency;
  final double principal,
      annualInterestRate,
      estimatedMonthlyPayment,
      estimatedTotalInterest,
      estimatedTotalRepayment;
  final int termMonths;
  final LoanApplicationStatus status;
  final DateTime submittedAtUtc;
  final DateTime? reviewedAtUtc;
  final String? adminNote;
  bool get isPending => status == LoanApplicationStatus.pending;
  bool get isApproved => status == LoanApplicationStatus.approved;
  bool get isRejected => status == LoanApplicationStatus.rejected;
}

LoanApplicationStatus _status(Object? raw) =>
    switch (raw?.toString().toLowerCase()) {
      '2' || 'approved' => LoanApplicationStatus.approved,
      '3' || 'rejected' => LoanApplicationStatus.rejected,
      _ => LoanApplicationStatus.pending,
    };

enum LoanStatus { active, completed }

enum LoanInstallmentStatus { pending, paid }

LoanStatus _loanStatus(Object? raw) =>
    raw?.toString().toLowerCase() == 'completed' || raw?.toString() == '2'
    ? LoanStatus.completed
    : LoanStatus.active;

class LoanModel {
  const LoanModel({
    required this.loanId,
    required this.applicationId,
    required this.status,
    required this.productName,
    required this.originalPrincipal,
    required this.outstandingPrincipal,
    required this.currency,
    required this.annualInterestRate,
    required this.termMonths,
    required this.monthlyPayment,
    required this.totalRepayment,
    required this.totalPaid,
    required this.startDateUtc,
    required this.nextPaymentDateUtc,
    required this.maturityDateUtc,
    required this.paidInstallments,
    required this.remainingInstallments,
    required this.destinationAccountId,
    required this.destinationAccountNumber,
  });
  factory LoanModel.fromJson(Map<String, dynamic> json) => LoanModel(
    loanId: json['loanId']?.toString() ?? '',
    applicationId: json['applicationId']?.toString() ?? '',
    status: _loanStatus(json['status']),
    productName: json['productName']?.toString() ?? 'Loan',
    originalPrincipal: _number(json, 'originalPrincipal'),
    outstandingPrincipal: _number(json, 'outstandingPrincipal'),
    currency: json['currency']?.toString() ?? '',
    annualInterestRate: _number(json, 'annualInterestRate'),
    termMonths: (json['termMonths'] as num? ?? 0).toInt(),
    monthlyPayment: _number(json, 'monthlyPayment'),
    totalRepayment: _number(json, 'totalRepayment'),
    totalPaid: _number(json, 'totalPaid'),
    startDateUtc:
        DateTime.tryParse(json['startDateUtc']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    nextPaymentDateUtc: DateTime.tryParse(
      json['nextPaymentDateUtc']?.toString() ?? '',
    ),
    maturityDateUtc:
        DateTime.tryParse(json['maturityDateUtc']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    paidInstallments: (json['paidInstallments'] as num? ?? 0).toInt(),
    remainingInstallments: (json['remainingInstallments'] as num? ?? 0).toInt(),
    destinationAccountId: json['destinationAccountId']?.toString() ?? '',
    destinationAccountNumber:
        json['destinationAccountNumber']?.toString() ?? '',
  );
  final String loanId,
      applicationId,
      productName,
      currency,
      destinationAccountId,
      destinationAccountNumber;
  final LoanStatus status;
  final double originalPrincipal,
      outstandingPrincipal,
      annualInterestRate,
      monthlyPayment,
      totalRepayment,
      totalPaid;
  final int termMonths, paidInstallments, remainingInstallments;
  final DateTime startDateUtc, maturityDateUtc;
  final DateTime? nextPaymentDateUtc;
  bool get isCompleted => status == LoanStatus.completed;
}

class LoanInstallmentModel {
  const LoanInstallmentModel({
    required this.id,
    required this.installmentNumber,
    required this.dueDateUtc,
    required this.scheduledAmount,
    required this.principalAmount,
    required this.interestAmount,
    required this.remainingPrincipalAfter,
    required this.status,
    this.paidAtUtc,
  });
  factory LoanInstallmentModel.fromJson(Map<String, dynamic> json) =>
      LoanInstallmentModel(
        id: json['id']?.toString() ?? '',
        installmentNumber: (json['installmentNumber'] as num? ?? 0).toInt(),
        dueDateUtc:
            DateTime.tryParse(json['dueDateUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        scheduledAmount: _number(json, 'scheduledAmount'),
        principalAmount: _number(json, 'principalAmount'),
        interestAmount: _number(json, 'interestAmount'),
        remainingPrincipalAfter: _number(json, 'remainingPrincipalAfter'),
        status:
            json['status']?.toString().toLowerCase() == 'paid' ||
                json['status']?.toString() == '2'
            ? LoanInstallmentStatus.paid
            : LoanInstallmentStatus.pending,
        paidAtUtc: DateTime.tryParse(json['paidAtUtc']?.toString() ?? ''),
      );
  final String id;
  final int installmentNumber;
  final DateTime dueDateUtc;
  final double scheduledAmount,
      principalAmount,
      interestAmount,
      remainingPrincipalAfter;
  final LoanInstallmentStatus status;
  final DateTime? paidAtUtc;
  bool get isPaid => status == LoanInstallmentStatus.paid;
}

class LoanPaymentModel {
  const LoanPaymentModel({
    required this.paymentId,
    required this.installmentNumber,
    required this.amount,
    required this.principalAmount,
    required this.interestAmount,
    required this.paidAtUtc,
    required this.sourceAccountNumber,
    required this.transactionReference,
  });
  factory LoanPaymentModel.fromJson(Map<String, dynamic> json) =>
      LoanPaymentModel(
        paymentId: json['paymentId']?.toString() ?? '',
        installmentNumber: (json['installmentNumber'] as num? ?? 0).toInt(),
        amount: _number(json, 'amount'),
        principalAmount: _number(json, 'principalAmount'),
        interestAmount: _number(json, 'interestAmount'),
        paidAtUtc:
            DateTime.tryParse(json['paidAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sourceAccountNumber: json['sourceAccountNumber']?.toString() ?? '',
        transactionReference: json['transactionReference']?.toString() ?? '',
      );
  final String paymentId, sourceAccountNumber, transactionReference;
  final int installmentNumber;
  final double amount, principalAmount, interestAmount;
  final DateTime paidAtUtc;
}

class LoanDetailsModel {
  const LoanDetailsModel({
    required this.loan,
    required this.installments,
    required this.payments,
  });
  factory LoanDetailsModel.fromJson(Map<String, dynamic> json) =>
      LoanDetailsModel(
        loan: LoanModel.fromJson(json['loan'] as Map<String, dynamic>? ?? {}),
        installments: (json['installments'] as List? ?? [])
            .map(
              (e) => LoanInstallmentModel.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        payments: (json['payments'] as List? ?? [])
            .map((e) => LoanPaymentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final LoanModel loan;
  final List<LoanInstallmentModel> installments;
  final List<LoanPaymentModel> payments;
}

class LoanPaymentQuoteModel {
  const LoanPaymentQuoteModel({
    required this.loanId,
    required this.installmentId,
    required this.installmentNumber,
    required this.dueDateUtc,
    required this.amount,
    required this.principalAmount,
    required this.interestAmount,
    required this.currency,
    required this.outstandingBefore,
    required this.outstandingAfter,
    required this.isFinalInstallment,
  });
  factory LoanPaymentQuoteModel.fromJson(Map<String, dynamic> json) =>
      LoanPaymentQuoteModel(
        loanId: json['loanId']?.toString() ?? '',
        installmentId: json['installmentId']?.toString() ?? '',
        installmentNumber: (json['installmentNumber'] as num? ?? 0).toInt(),
        dueDateUtc:
            DateTime.tryParse(json['dueDateUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        amount: _number(json, 'amount'),
        principalAmount: _number(json, 'principalAmount'),
        interestAmount: _number(json, 'interestAmount'),
        currency: json['currency']?.toString() ?? '',
        outstandingBefore: _number(json, 'outstandingBefore'),
        outstandingAfter: _number(json, 'outstandingAfter'),
        isFinalInstallment: json['isFinalInstallment'] == true,
      );
  final String loanId, installmentId, currency;
  final int installmentNumber;
  final DateTime dueDateUtc;
  final double amount,
      principalAmount,
      interestAmount,
      outstandingBefore,
      outstandingAfter;
  final bool isFinalInstallment;
}

class LoanPaymentResultModel {
  const LoanPaymentResultModel({
    required this.paymentId,
    required this.loanId,
    required this.installmentNumber,
    required this.amount,
    required this.principalAmount,
    required this.interestAmount,
    required this.currency,
    required this.outstandingPrincipal,
    required this.nextPaymentDateUtc,
    required this.loanStatus,
    required this.transactionReference,
    required this.paidAtUtc,
  });
  factory LoanPaymentResultModel.fromJson(Map<String, dynamic> json) =>
      LoanPaymentResultModel(
        paymentId: json['paymentId']?.toString() ?? '',
        loanId: json['loanId']?.toString() ?? '',
        installmentNumber: (json['installmentNumber'] as num? ?? 0).toInt(),
        amount: _number(json, 'amount'),
        principalAmount: _number(json, 'principalAmount'),
        interestAmount: _number(json, 'interestAmount'),
        currency: json['currency']?.toString() ?? '',
        outstandingPrincipal: _number(json, 'outstandingPrincipal'),
        nextPaymentDateUtc: DateTime.tryParse(
          json['nextPaymentDateUtc']?.toString() ?? '',
        ),
        loanStatus: _loanStatus(json['loanStatus']),
        transactionReference: json['transactionReference']?.toString() ?? '',
        paidAtUtc:
            DateTime.tryParse(json['paidAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
  final String paymentId, loanId, currency, transactionReference;
  final int installmentNumber;
  final double amount, principalAmount, interestAmount, outstandingPrincipal;
  final DateTime? nextPaymentDateUtc;
  final LoanStatus loanStatus;
  final DateTime paidAtUtc;
  bool get isCompleted => loanStatus == LoanStatus.completed;
}
