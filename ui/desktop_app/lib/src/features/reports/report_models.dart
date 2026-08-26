class ReportJobModel {
  const ReportJobModel({
    required this.id,
    required this.type,
    required this.status,
    required this.requestedBy,
    required this.requestedAtUtc,
    this.completedAtUtc,
    this.fileName,
    required this.downloadAvailable,
    this.errorMessage,
  });
  factory ReportJobModel.fromJson(Map<String, dynamic> json) => ReportJobModel(
    id: json['id'] as String,
    type: json['type'].toString(),
    status: json['status'].toString(),
    requestedBy: json['requestedBy'] as String? ?? '',
    requestedAtUtc: DateTime.parse(json['requestedAtUtc'] as String),
    completedAtUtc: json['completedAtUtc'] == null
        ? null
        : DateTime.parse(json['completedAtUtc'] as String),
    fileName: json['fileName'] as String?,
    downloadAvailable: json['downloadAvailable'] as bool? ?? false,
    errorMessage: json['errorMessage'] as String?,
  );
  final String id, type, status, requestedBy;
  final DateTime requestedAtUtc;
  final DateTime? completedAtUtc;
  final String? fileName, errorMessage;
  final bool downloadAvailable;
  bool get active =>
      status == 'Queued' ||
      status == 'Processing' ||
      status == '1' ||
      status == '2';
  String get typeLabel => switch (type) {
    '1' => 'Transaction Report',
    '2' => 'Loan Portfolio Report',
    _ => type.replaceAll('Report', ' Report'),
  };
  String get statusLabel => switch (status) {
    '1' => 'Queued',
    '2' => 'Processing',
    '3' => 'Completed',
    '4' => 'Failed',
    _ => status,
  };
}

class ReportJobPageModel {
  const ReportJobPageModel(this.items, this.totalCount);
  factory ReportJobPageModel.fromJson(Map<String, dynamic> json) =>
      ReportJobPageModel(
        (json['items'] as List<dynamic>? ?? const [])
            .map((x) => ReportJobModel.fromJson(x as Map<String, dynamic>))
            .toList(),
        json['totalCount'] as int? ?? 0,
      );
  final List<ReportJobModel> items;
  final int totalCount;
}
