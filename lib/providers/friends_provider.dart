import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/friendship.dart';
import '../models/location_point.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class InAppNotice {
  const InAppNotice({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;
}

class FriendsProvider extends ChangeNotifier {
  List<Friendship> _friends = [];
  List<Friendship> _pendingRequests = [];
  Map<String, LocationPoint> _friendLocations = {};
  Map<String, List<LocationPoint>> _friendPaths = {};
  final Map<String, bool> _proximityAlertLocked = {};
  final Map<String, DateTime> _lastGreetingAlertAt = {};
  RealtimeChannel? _locationChannel;
  RealtimeChannel? _greetingChannel;
  InAppNotice? _latestNotice;
  bool _loading = false;

  List<Friendship> get friends => _friends;
  List<Friendship> get pendingRequests => _pendingRequests;
  Map<String, LocationPoint> get friendLocations => _friendLocations;
  Map<String, List<LocationPoint>> get friendPaths => _friendPaths;
  InAppNotice? get latestNotice => _latestNotice;
  bool get loading => _loading;

  int get onlineFriendCount =>
      _friendLocations.values.where((l) => l.isActive).length;

  Future<void> initialize(String userId) => loadFriends(userId);

  Future<void> refresh(String userId) => loadFriends(userId);

  Future<void> loadFriends(String userId) async {
    _loading = true;
    notifyListeners();

    _friends = await SupabaseService.getFriends(userId);
    _pendingRequests = await SupabaseService.getPendingRequests(userId);

    final ids = _friendIds(userId);
    if (ids.isNotEmpty) {
      final locations = await SupabaseService.getFriendLocations(ids);
      _friendLocations = {for (final l in locations) l.userId: l};

      _friendPaths = {};
      final histories = await Future.wait(
        ids.map((id) => SupabaseService.getLocationHistory(id)),
      );
      for (var i = 0; i < ids.length; i++) {
        _friendPaths[ids[i]] = histories[i].reversed.toList();
      }

      // 채널 교체 (중복 구독 방지)
      _subscribeToLocations(ids);
    } else {
      _friendLocations = {};
      _friendPaths = {};
      _proximityAlertLocked.clear();
      _locationChannel?.unsubscribe();
      _locationChannel = null;
    }

    _subscribeToGreetings(userId);

    _loading = false;
    notifyListeners();
  }

  void _subscribeToLocations(List<String> ids) {
    _locationChannel?.unsubscribe();
    _locationChannel = null;

    _locationChannel =
        SupabaseService.subscribeToFriendLocations(ids, (location) {
      _friendLocations[location.userId] = location;

      if (location.isActive) {
        final path = List<LocationPoint>.from(
          _friendPaths[location.userId] ?? [],
        );
        path.add(location);
        if (path.length > SupabaseConfig.pathHistoryLength) {
          path.removeAt(0);
        }
        _friendPaths[location.userId] = path;
      } else {
        _friendPaths.remove(location.userId);
      }

      notifyListeners();
    });
  }

  void _subscribeToGreetings(String userId) {
    _greetingChannel?.unsubscribe();
    _greetingChannel =
        SupabaseService.subscribeToGreetings(userId, _handleGreeting);
  }

  void _handleGreeting(Map<String, dynamic> data) {
    final senderId = data['sender_id'] as String?;
    if (senderId == null) return;

    final now = DateTime.now();
    final lastAlertAt = _lastGreetingAlertAt[senderId];
    if (lastAlertAt != null &&
        now.difference(lastAlertAt) <
            SupabaseConfig.greetingNotificationCooldown) {
      return;
    }
    _lastGreetingAlertAt[senderId] = now;

    final senderName =
        (data['sender_name'] as String?) ?? _findFriendProfile(senderId)?.name;
    final distanceMeters = (data['distance_meters'] as num?)?.toDouble() ?? 0;
    final displayName = senderName ?? '친구';
    final message =
        '${NotificationService.formatDistance(distanceMeters)}만큼 떨어져있는 $displayName이 인사합니다!';

    NotificationService.showGreetingAlert(
      senderName: displayName,
      distanceMeters: distanceMeters,
      senderId: senderId,
    );
    _setNotice(message);
  }

  void checkProximity(
    double myLat,
    double myLng, {
    double threshold = SupabaseConfig.proximityThresholdMeters,
    bool notificationsEnabled = true,
  }) {
    for (final entry in _friendLocations.entries) {
      final id = entry.key;
      final loc = entry.value;
      if (!loc.isActive) continue;

      final dist = LocationService.distanceBetween(
          myLat, myLng, loc.latitude, loc.longitude);

      if (dist <= threshold) {
        if (_proximityAlertLocked[id] != true) {
          _proximityAlertLocked[id] = true;
          final profile = _findFriendProfile(id);
          if (profile != null) {
            if (notificationsEnabled) {
              NotificationService.showProximityAlert(
                friendName: profile.name,
                distanceMeters: dist,
                friendId: id,
              );
            }
            _setNotice(
              '${profile.name}이 ${NotificationService.formatDistance(dist)} 안에 있습니다! 어서 인사해보세요!',
            );
          }
        }
      } else if (dist >= SupabaseConfig.proximityResetThresholdMeters) {
        _proximityAlertLocked[id] = false;
      }
    }
  }

  Future<void> sendGreeting({
    required UserProfile senderProfile,
    required UserProfile recipientProfile,
    required double distanceMeters,
  }) async {
    await SupabaseService.sendGreeting(
      recipientId: recipientProfile.id,
      senderName: senderProfile.name,
      distanceMeters: distanceMeters,
    );
    _setNotice('${recipientProfile.name}에게 인사했습니다!');
  }

  void _setNotice(String message) {
    _latestNotice = InAppNotice(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      message: message,
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  UserProfile? _findFriendProfile(String friendId) {
    for (final f in _friends) {
      if (f.requesterProfile?.id == friendId) return f.requesterProfile;
      if (f.addresseeProfile?.id == friendId) return f.addresseeProfile;
    }
    return null;
  }

  List<String> _friendIds(String currentUserId) =>
      _friends.map((f) => f.friendId(currentUserId)).toList();

  UserProfile? getFriendProfile(String friendId) =>
      _findFriendProfile(friendId);

  Future<void> sendFriendRequest(String addresseeId) =>
      SupabaseService.sendFriendRequest(addresseeId);

  Future<void> respondToRequest(
      String friendshipId, bool accept, String userId) async {
    await SupabaseService.respondToFriendRequest(friendshipId, accept);
    await loadFriends(userId);
  }

  Future<void> removeFriend(String friendshipId, String userId) async {
    await SupabaseService.removeFriend(friendshipId);
    await loadFriends(userId);
  }

  Future<List<UserProfile>> searchUsers(String query) =>
      SupabaseService.searchUsers(query);

  @override
  void dispose() {
    _locationChannel?.unsubscribe();
    _greetingChannel?.unsubscribe();
    super.dispose();
  }
}
