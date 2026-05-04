import 'dart:typed_data';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../models/location_point.dart';
import '../models/friendship.dart';
import '../models/recording_room.dart';
import '../models/recording_session.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const int _maxAvatarBytes = 2 * 1024 * 1024;
  static const Set<String> _allowedAvatarExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };
  static const Set<String> _allowedAvatarContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };
  static const String _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ─── Auth ───────────────────────────────────────────────────────────────────

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
    String? phone,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedDisplayName = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : normalizedUsername;
    final normalizedPhone =
        (phone?.trim().isNotEmpty ?? false) ? phone!.trim() : null;

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
      data: {
        'username': normalizedUsername,
        'display_name': normalizedDisplayName,
        if (normalizedPhone != null) 'phone': normalizedPhone,
      },
    );

    // 이메일 확인이 꺼져 있으면 즉시 세션이 생기므로 클라이언트에서도 보강한다.
    // 이메일 확인이 켜져 있으면 DB 트리거(handle_new_user)가 프로필을 생성한다.
    if (response.user != null && response.session != null) {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'username': normalizedUsername,
        'display_name': normalizedDisplayName,
        'email': email.trim(),
        if (normalizedPhone != null) 'phone': normalizedPhone,
      }, onConflict: 'id');
    }
    return response;
  }

  static Future<void> signOut() => _client.auth.signOut();

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ─── Profile ────────────────────────────────────────────────────────────────

  static Future<UserProfile?> getProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final safeUpdates = Map<String, dynamic>.fromEntries(
      updates.entries.where(
        (entry) => const {
          'display_name',
          'avatar_url',
          'phone',
          'is_sharing_location',
        }.contains(entry.key),
      ),
    );
    if (safeUpdates.isEmpty) return;
    await _client.from('profiles').update(safeUpdates).eq('id', userId);
  }

  static Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      throw StateError('로그인이 필요합니다.');
    }
    if (bytes.isEmpty || bytes.length > _maxAvatarBytes) {
      throw ArgumentError('프로필 사진은 2MB 이하만 업로드할 수 있습니다.');
    }

    final normalizedExtension =
        extension.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final safeExtension = normalizedExtension.isEmpty
        ? 'jpg'
        : normalizedExtension == 'jpeg'
            ? 'jpg'
            : normalizedExtension;
    final safeContentType = contentType.toLowerCase();
    if (!_allowedAvatarExtensions.contains(safeExtension) ||
        !_allowedAvatarContentTypes.contains(safeContentType)) {
      throw ArgumentError('지원하지 않는 프로필 사진 형식입니다.');
    }
    final path = '$userId/avatar.$safeExtension';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );

    final url = _client.storage.from('avatars').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<List<UserProfile>> searchUsers(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return [];

    final data = await _client.rpc(
      'search_profiles',
      params: {'p_query': normalizedQuery},
    );
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  // ─── Location ───────────────────────────────────────────────────────────────

  static Future<void> upsertLocation(LocationPoint location) async {
    await _client.from('locations').upsert(
      {
        'user_id': location.userId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'speed': location.speed,
        'heading': location.heading,
        'accuracy': location.accuracy,
        'is_online': location.isOnline,
        'current_room_id': location.roomId,
        'current_session_id': location.sessionId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  static Future<void> setLocationOnlineStatus(
    String userId,
    bool isOnline,
  ) async {
    await _client.from('locations').update({
      'is_online': isOnline,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  static Future<void> insertLocationHistory(LocationPoint location) async {
    await _client.from('location_history').insert({
      'user_id': location.userId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'speed': location.speed,
      'heading': location.heading,
      'room_id': location.roomId,
      'session_id': location.sessionId,
    });
  }

  static Future<List<LocationPoint>> getFriendLocations(
      List<String> friendIds) async {
    if (friendIds.isEmpty) return [];
    final data =
        await _client.from('locations').select().inFilter('user_id', friendIds);
    return (data as List).map((e) => LocationPoint.fromJson(e)).toList();
  }

  static Future<List<LocationPoint>> getLocationHistory(
    String userId, {
    int limit = SupabaseConfig.pathHistoryLength,
  }) async {
    final data = await _client
        .from('location_history')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => LocationPoint.fromJson(e)).toList();
  }

  // ─── Realtime ───────────────────────────────────────────────────────────────

  static RealtimeChannel subscribeToFriendLocations(
    List<String> friendIds,
    void Function(LocationPoint) onUpdate,
  ) {
    return _client
        .channel('friend_locations_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final location = LocationPoint.fromJson(payload.newRecord);
              if (friendIds.contains(location.userId)) {
                onUpdate(location);
              }
            }
          },
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToGreetings(
    String userId,
    void Function(Map<String, dynamic>) onGreeting,
  ) {
    return _client
        .channel('friend_greetings_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_greetings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onGreeting(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  static Future<void> sendGreeting({
    required String recipientId,
    required double distanceMeters,
  }) async {
    await _client.rpc('send_friend_greeting', params: {
      'p_recipient_id': recipientId,
      'p_distance_meters': distanceMeters,
    });
  }

  // ─── Friendships ─────────────────────────────────────────────────────────────

  static Future<List<Friendship>> getFriends(String userId) async {
    final data = await _client
        .from('friendships')
        .select(
            '*, requester:profiles!requester_id(*), addressee:profiles!addressee_id(*)')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .eq('status', 'accepted');
    return (data as List).map((e) => Friendship.fromJson(e)).toList();
  }

  static Future<List<Friendship>> getPendingRequests(String userId) async {
    final data = await _client
        .from('friendships')
        .select('*, requester:profiles!requester_id(*)')
        .eq('addressee_id', userId)
        .eq('status', 'pending');
    return (data as List).map((e) => Friendship.fromJson(e)).toList();
  }

  static Future<void> sendFriendRequest(String addresseeId) async {
    await _client.from('friendships').insert({
      'requester_id': currentUser!.id,
      'addressee_id': addresseeId,
    });
  }

  static Future<void> respondToFriendRequest(
      String friendshipId, bool accept) async {
    await _client.from('friendships').update({
      'status': accept ? 'accepted' : 'rejected',
    }).eq('id', friendshipId);
  }

  static Future<void> removeFriend(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  // ─── Recording Rooms ───────────────────────────────────────────────────────

  static Future<List<RecordingRoom>> getMyRooms(String userId) async {
    final data = await _client
        .from('room_members')
        .select('room:recording_rooms(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return (data as List)
        .map((row) => RecordingRoom.fromJson(row['room']))
        .where((room) => !room.isExpired)
        .toList();
  }

  static Future<RecordingRoom> createRoom({
    required String creatorId,
    required String name,
    required int retentionDays,
  }) async {
    final now = DateTime.now().toUtc();
    final days =
        retentionDays.clamp(1, SupabaseConfig.maxRoomRetentionDays).toInt();
    final room = await _client
        .from('recording_rooms')
        .insert({
          'creator_id': creatorId,
          'name': name.trim().isEmpty ? '새 기록방' : name.trim(),
          'invite_code': _inviteCode(),
          'retention_days': days,
          'expires_at': now.add(Duration(days: days)).toIso8601String(),
        })
        .select()
        .single();

    await _client.from('room_members').insert({
      'room_id': room['id'],
      'user_id': creatorId,
      'role': 'owner',
    });

    return RecordingRoom.fromJson(room);
  }

  static Future<RecordingRoom> joinRoomByInviteCode(String inviteCode) async {
    final roomId = await _client.rpc(
      'join_room_by_code',
      params: {'p_invite_code': inviteCode.trim().toUpperCase()},
    ) as String;

    final room = await _client
        .from('recording_rooms')
        .select()
        .eq('id', roomId)
        .single();
    return RecordingRoom.fromJson(room);
  }

  static Future<List<UserProfile>> getRoomMembers(String roomId) async {
    final data = await _client.rpc(
      'get_room_members_public',
      params: {'p_room_id': roomId},
    );

    return (data as List).map((row) => UserProfile.fromJson(row)).toList();
  }

  static Future<List<LocationPoint>> getRoomLocations(String roomId) async {
    final data = await _client
        .from('locations')
        .select()
        .eq('current_room_id', roomId)
        .eq('is_online', true);

    return (data as List).map((e) => LocationPoint.fromJson(e)).toList();
  }

  static Future<Map<String, List<LocationPoint>>> getRoomLocationHistory(
    String roomId,
  ) async {
    final data = await _client
        .from('location_history')
        .select()
        .eq('room_id', roomId)
        .order('recorded_at', ascending: true);

    final result = <String, List<LocationPoint>>{};
    for (final row in data as List) {
      final point = LocationPoint.fromJson(row);
      result.putIfAbsent(point.userId, () => []).add(point);
    }
    return result;
  }

  static RealtimeChannel subscribeToRoomLocations(
    String roomId,
    void Function(LocationPoint) onUpdate,
  ) {
    return _client
        .channel(
            'room_locations_${roomId}_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          callback: (payload) {
            if (payload.newRecord.isEmpty) return;
            final location = LocationPoint.fromJson(payload.newRecord);
            if (location.roomId == roomId) onUpdate(location);
          },
        )
        .subscribe();
  }

  static Future<RecordingSession> createRecordingSession({
    required String roomId,
    required String userId,
  }) async {
    final data = await _client
        .from('recording_sessions')
        .insert({
          'room_id': roomId,
          'user_id': userId,
        })
        .select()
        .single();
    return RecordingSession.fromJson(data);
  }

  static Future<RecordingSession> finishRecordingSession({
    required String sessionId,
    required double totalDistanceMeters,
    required List<String> metFriendIds,
  }) async {
    final data = await _client
        .from('recording_sessions')
        .update({
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          'total_distance_meters': totalDistanceMeters,
          'met_friend_ids': metFriendIds,
          'summary': {
            'total_distance_meters': totalDistanceMeters,
            'met_friend_ids': metFriendIds,
          },
        })
        .eq('id', sessionId)
        .select()
        .single();
    return RecordingSession.fromJson(data);
  }

  static String _inviteCode() {
    final random = Random.secure();
    return List.generate(
      12,
      (_) => _inviteAlphabet[random.nextInt(_inviteAlphabet.length)],
    ).join();
  }
}
