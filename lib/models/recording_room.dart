class RecordingRoom {
  final String id;
  final String creatorId;
  final String name;
  final String inviteCode;
  final int retentionDays;
  final DateTime expiresAt;
  final DateTime createdAt;

  const RecordingRoom({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.inviteCode,
    required this.retentionDays,
    required this.expiresAt,
    required this.createdAt,
  });

  factory RecordingRoom.fromJson(Map<String, dynamic> json) {
    return RecordingRoom(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      retentionDays: (json['retention_days'] as num).toInt(),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  String get shareLink => 'radar://room/$inviteCode';
}
