class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final bool isSharingLocation;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.phone,
    this.email,
    this.isSharingLocation = true,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      isSharingLocation: json['is_sharing_location'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'email': email,
        'is_sharing_location': isSharingLocation,
      };

  String get name => displayName ?? username;

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? phone,
    bool? isSharingLocation,
  }) {
    return UserProfile(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      email: email,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
      createdAt: createdAt,
    );
  }
}
