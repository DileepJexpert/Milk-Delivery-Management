enum ChangeRequestType { pause, quantityChange }

enum ChangeRequestStatus { pending, applied, cancelled }

class ChangeRequest {
  ChangeRequest({
    required this.id,
    required this.flatId,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.requestedByPhone,
    required this.type,
    required this.fromDateKey,
    required this.toDateKey,
    required this.newQuantity,
    required this.status,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String flatId;
  final String requestedByUserId;
  final String requestedByName;
  final String requestedByPhone;
  final ChangeRequestType type;
  final String fromDateKey;
  final String toDateKey;
  final double newQuantity;
  final ChangeRequestStatus status;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'requestedByUserId': requestedByUserId,
        'requestedByName': requestedByName,
        'requestedByPhone': requestedByPhone,
        'type': type.name,
        'fromDateKey': fromDateKey,
        'toDateKey': toDateKey,
        'newQuantity': newQuantity,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory ChangeRequest.fromJson(Map json) => ChangeRequest(
        id: json['id'] as String,
        flatId: (json['flatId'] ?? json['flat_id']) as String,
        requestedByUserId: (json['requestedByUserId'] ?? json['requested_by_user_id'] ?? '') as String,
        requestedByName: (json['requestedByName'] ?? json['requested_by_name'] ?? '') as String,
        requestedByPhone: (json['requestedByPhone'] ?? json['requested_by_phone'] ?? '') as String,
        type: ChangeRequestType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ChangeRequestType.pause,
        ),
        fromDateKey: (json['fromDateKey'] ?? json['from_date_key'] ?? json['start_date'] ?? '') as String,
        toDateKey: (json['toDateKey'] ?? json['to_date_key'] ?? json['end_date'] ?? '') as String,
        newQuantity: ((json['newQuantity'] ?? json['new_quantity'] ?? json['requested_quantity'] ?? 0) as num).toDouble(),
        status: ChangeRequestStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ChangeRequestStatus.pending,
        ),
        createdAt: (json['createdAt'] ?? json['created_at']) == null
            ? DateTime.now()
            : DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
        note: (json['note'] ?? json['reason']) as String?,
      );

  ChangeRequest copyWith({ChangeRequestStatus? status}) => ChangeRequest(
        id: id,
        flatId: flatId,
        requestedByUserId: requestedByUserId,
        requestedByName: requestedByName,
        requestedByPhone: requestedByPhone,
        type: type,
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
        newQuantity: newQuantity,
        status: status ?? this.status,
        createdAt: createdAt,
        note: note,
      );
}
