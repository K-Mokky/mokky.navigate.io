import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/location_point.dart';
import '../models/recording_room.dart';
import '../models/recording_session.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import 'location_provider.dart';

class RoomsProvider extends ChangeNotifier {
  List<RecordingRoom> _rooms = [];
  RecordingRoom? _activeRoom;
  RecordingSession? _activeSession;
  List<UserProfile> _members = [];
  Map<String, LocationPoint> _memberLocations = {};
  Map<String, List<LocationPoint>> _memberPaths = {};
  RecordingSummary? _lastSummary;
  RealtimeChannel? _roomChannel;
  bool _loading = false;
  String? _error;

  List<RecordingRoom> get rooms => _rooms;
  RecordingRoom? get activeRoom => _activeRoom;
  RecordingSession? get activeSession => _activeSession;
  List<UserProfile> get members => _members;
  Map<String, LocationPoint> get memberLocations => _memberLocations;
  Map<String, List<LocationPoint>> get memberPaths => _memberPaths;
  RecordingSummary? get lastSummary => _lastSummary;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasActiveRoom => _activeRoom != null;
  bool get isRecording => _activeSession?.isActive == true;

  Future<void> initialize(String userId) => loadRooms(userId);

  Future<void> loadRooms(String userId) async {
    _setLoading(true);
    try {
      _rooms = await SupabaseService.getMyRooms(userId);
      if (_activeRoom == null && _rooms.isNotEmpty) {
        _activeRoom = _rooms.first;
      }
      if (_activeRoom != null) {
        await _loadRoomDetails(_activeRoom!.id);
      }
      _error = null;
    } catch (error) {
      _error = '기록방 정보를 불러오지 못했습니다.';
      debugPrint('Load rooms failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createRoom({
    required String userId,
    required String name,
    int retentionDays = SupabaseConfig.defaultRoomRetentionDays,
  }) async {
    _setLoading(true);
    try {
      final room = await SupabaseService.createRoom(
        creatorId: userId,
        name: name,
        retentionDays: retentionDays,
      );
      _activeRoom = room;
      await loadRooms(userId);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinRoom(String inviteCode, String userId) async {
    _setLoading(true);
    try {
      _activeRoom = await SupabaseService.joinRoomByInviteCode(inviteCode);
      await loadRooms(userId);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectRoom(RecordingRoom room) async {
    _activeRoom = room;
    await _loadRoomDetails(room.id);
    notifyListeners();
  }

  Future<bool> startRecording({
    required String userId,
    required LocationProvider locationProvider,
  }) async {
    final room = _activeRoom;
    if (room == null || room.isExpired) return false;

    _setLoading(true);
    try {
      final ready = await locationProvider.startTracking(
        userId,
        sharingEnabled: true,
      );
      if (!ready) return false;

      final session = await SupabaseService.createRecordingSession(
        roomId: room.id,
        userId: userId,
      );
      _activeSession = session;
      _lastSummary = null;
      await locationProvider.beginRoomRecording(
        userId: userId,
        roomId: room.id,
        sessionId: session.id,
      );
      notifyListeners();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  Future<RecordingSummary?> stopRecording({
    required String userId,
    required LocationProvider locationProvider,
  }) async {
    final session = _activeSession;
    if (session == null) return null;

    _setLoading(true);
    try {
      final distance = await locationProvider.endRoomRecording(userId);
      final finished = await SupabaseService.finishRecordingSession(
        sessionId: session.id,
        totalDistanceMeters: distance,
        metFriendIds: const [],
      );
      _activeSession = finished;
      _lastSummary = RecordingSummary(
        totalDistanceMeters: distance,
        metFriendIds: const [],
        startedAt: session.startedAt,
        endedAt: finished.endedAt ?? DateTime.now(),
      );
      await _loadRoomDetails(session.roomId);
      notifyListeners();
      return _lastSummary;
    } finally {
      _setLoading(false);
    }
  }

  UserProfile? memberProfile(String userId) {
    for (final member in _members) {
      if (member.id == userId) return member;
    }
    return null;
  }

  Future<void> _loadRoomDetails(String roomId) async {
    _members = await SupabaseService.getRoomMembers(roomId);
    final locations = await SupabaseService.getRoomLocations(roomId);
    _memberLocations = {for (final loc in locations) loc.userId: loc};
    _memberPaths = await SupabaseService.getRoomLocationHistory(roomId);
    _subscribeToRoom(roomId);
  }

  void _subscribeToRoom(String roomId) {
    _roomChannel?.unsubscribe();
    _roomChannel = SupabaseService.subscribeToRoomLocations(roomId, (location) {
      if (location.isActive) {
        _memberLocations[location.userId] = location;
        final path = List<LocationPoint>.from(
          _memberPaths[location.userId] ?? const [],
        );
        path.add(location);
        _memberPaths[location.userId] = path;
      } else {
        _memberLocations.remove(location.userId);
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    super.dispose();
  }
}
