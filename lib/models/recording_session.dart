class RecordingSession {
  final String id;
  final String roomId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double totalDistanceMeters;
  final List<String> metFriendIds;

  const RecordingSession({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.totalDistanceMeters = 0,
    this.metFriendIds = const [],
  });

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      totalDistanceMeters:
          (json['total_distance_meters'] as num?)?.toDouble() ?? 0,
      metFriendIds: ((json['met_friend_ids'] as List?) ?? const [])
          .map((id) => id as String)
          .toList(),
    );
  }

  bool get isActive => endedAt == null;
}

class RecordingSummary {
  final double totalDistanceMeters;
  final List<String> metFriendIds;
  final DateTime startedAt;
  final DateTime endedAt;

  const RecordingSummary({
    required this.totalDistanceMeters,
    required this.metFriendIds,
    required this.startedAt,
    required this.endedAt,
  });

  double get totalDistanceKm => totalDistanceMeters / 1000;
  Duration get duration => endedAt.difference(startedAt);
}
