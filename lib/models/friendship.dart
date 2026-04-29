import 'user_profile.dart';

enum FriendshipStatus { pending, accepted, rejected }

class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;

  final UserProfile? requesterProfile;
  final UserProfile? addresseeProfile;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.requesterProfile,
    this.addresseeProfile,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: FriendshipStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String),
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterProfile: json['requester'] != null
          ? UserProfile.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      addresseeProfile: json['addressee'] != null
          ? UserProfile.fromJson(json['addressee'] as Map<String, dynamic>)
          : null,
    );
  }

  UserProfile? friendProfile(String currentUserId) {
    if (requesterId == currentUserId) return addresseeProfile;
    if (addresseeId == currentUserId) return requesterProfile;
    return null;
  }

  String friendId(String currentUserId) {
    return requesterId == currentUserId ? addresseeId : requesterId;
  }
}
