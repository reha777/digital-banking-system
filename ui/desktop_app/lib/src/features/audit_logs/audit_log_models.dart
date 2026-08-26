class AuditLogPageModel {
  const AuditLogPageModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });
  factory AuditLogPageModel.fromJson(Map<String, dynamic> json) =>
      AuditLogPageModel(
        items: (json['items'] as List? ?? [])
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalCount: json['totalCount'] as int? ?? 0,
      );
  final List<AuditLogEntry> items;
  final int page, pageSize, totalCount;
  int get totalPages =>
      totalCount == 0 ? 1 : ((totalCount + pageSize - 1) / pageSize).floor();
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.actionDisplayName,
    required this.entityType,
    required this.entityId,
    required this.description,
    required this.createdAtUtc,
    this.reason,
    this.oldValue,
    this.newValue,
    this.correlationId,
  });
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: json['id'].toString(),
    actorName: json['actorName']?.toString() ?? '',
    actorRole: json['actorRole']?.toString() ?? '',
    action: json['action']?.toString() ?? '',
    actionDisplayName: json['actionDisplayName']?.toString() ?? '',
    entityType: json['entityType']?.toString() ?? '',
    entityId: json['entityId']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    reason: json['reason']?.toString(),
    oldValue: json['oldValue']?.toString(),
    newValue: json['newValue']?.toString(),
    correlationId: json['correlationId']?.toString(),
    createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
  );
  final String id,
      actorName,
      actorRole,
      action,
      actionDisplayName,
      entityType,
      entityId,
      description;
  final String? reason, oldValue, newValue, correlationId;
  final DateTime createdAtUtc;
}
