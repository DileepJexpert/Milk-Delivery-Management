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
        flatId: json['flatId'] as String,
        requestedByUserId: json['requestedByUserId'] as String,
        requestedByName: json['requestedByName'] as String,
        requestedByPhone: json['requestedByPhone'] as String,
        type: ChangeRequestType.values
            .firstWhere((t) => t.name == json['type']),
        fromDateKey: json['fromDateKey'] as String,
        toDateKey: json['toDateKey'] as String,
        newQuantity: (json['newQuantity'] as num).toDouble(),
        status: ChangeRequestStatus.values
            .firstWhere((s) => s.name == json['status']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String?,
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
