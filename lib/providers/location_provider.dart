import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/supabase_config.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  bool _permissionDenied = false;
  bool _isSharingLocation = true;
  String? _recordingRoomId;
  String? _recordingSessionId;
  DateTime? _recordingStartedAt;
  DateTime? _lastUploadAt;
  Position? _lastRecordedPosition;
  Timer? _recordingUploadTimer;
  double _recordingDistanceMeters = 0;

  // 내 이동 경로 (지도에 표시)
  final List<LocationPoint> _ownPath = [];

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionDenied => _permissionDenied;
  bool get isSharingLocation => _isSharingLocation;
  bool get isRecording => _recordingRoomId != null;
  String? get recordingRoomId => _recordingRoomId;
  String? get recordingSessionId => _recordingSessionId;
  DateTime? get recordingStartedAt => _recordingStartedAt;
  double get recordingDistanceMeters => _recordingDistanceMeters;
  List<LocationPoint> get ownPath => List.unmodifiable(_ownPath);

  LatLng? get currentLatLng => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  double get currentSpeed {
    final speed = _currentPosition?.speed ?? 0;
    return speed < 0 ? 0 : speed;
  }

  double get currentSpeedKmh => currentSpeed * 3.6;
  double get currentHeading => _currentPosition?.heading ?? 0;

  Future<bool> startTracking(String userId,
      {bool sharingEnabled = true}) async {
    // 이미 추적 중이면 공유 설정만 업데이트
    if (_isTracking) {
      await setLocationSharing(sharingEnabled, userId: userId);
      return true;
    }

    final permitted = await LocationService.requestPermission();
    if (!permitted) {
      _permissionDenied = true;
      notifyListeners();
      return false;
    }

    _isTracking = true;
    _isSharingLocation = sharingEnabled;
    _permissionDenied = false;
    notifyListeners();

    if (!_isSharingLocation) {
      try {
        await SupabaseService.setLocationOnlineStatus(userId, false);
      } catch (error) {
        debugPrint('Location offline sync failed: $error');
      }
    }

    // 초기 위치 즉시 취득
    final initial = await LocationService.getCurrentPosition();
    if (initial != null) {
      _currentPosition = initial;
      _addToOwnPath(userId, initial);
      notifyListeners();
      if (_isSharingLocation) await _safeUpload(userId, initial, force: true);
    }

    LocationService.startTracking((position) async {
      _currentPosition = position;
      _addToOwnPath(userId, position);
      notifyListeners();
      if (_isSharingLocation) await _safeUpload(userId, position);
    });

    return true;
  }

  Future<void> setLocationSharing(bool enabled, {String? userId}) async {
    _isSharingLocation = enabled;
    notifyListeners();

    if (userId == null) return;

    if (!enabled) {
      try {
        await SupabaseService.setLocationOnlineStatus(userId, false);
      } catch (error) {
        debugPrint('Location offline sync failed: $error');
      }
      return;
    }

    final current = _currentPosition;
    if (current != null) {
      await _safeUpload(userId, current, force: true);
    }
  }

  Future<void> beginRoomRecording({
    required String userId,
    required String roomId,
    required String sessionId,
  }) async {
    _recordingRoomId = roomId;
    _recordingSessionId = sessionId;
    _recordingStartedAt = DateTime.now();
    _recordingDistanceMeters = 0;
    _lastRecordedPosition = null;
    _lastUploadAt = null;
    _ownPath.clear();
    _isSharingLocation = true;
    notifyListeners();

    final current =
        _currentPosition ?? await LocationService.getCurrentPosition();
    if (current != null) {
      _currentPosition = current;
      await _safeUpload(userId, current, force: true);
    }

    _recordingUploadTimer?.cancel();
    _recordingUploadTimer = Timer.periodic(
      SupabaseConfig.locationUploadInterval,
      (_) {
        final latest = _currentPosition;
        if (latest != null && isRecording) {
          unawaited(_safeUpload(userId, latest));
        }
      },
    );
  }

  Future<double> endRoomRecording(String userId) async {
    _recordingUploadTimer?.cancel();
    _recordingUploadTimer = null;

    final current = _currentPosition;
    if (current != null && isRecording) {
      await _safeUpload(userId, current, force: true);
    }

    final distance = _recordingDistanceMeters;
    _recordingRoomId = null;
    _recordingSessionId = null;
    _recordingStartedAt = null;
    _lastRecordedPosition = null;
    _lastUploadAt = null;

    if (current != null) {
      await _safeUpload(userId, current, force: true, writeHistory: false);
    }

    notifyListeners();
    return distance;
  }

  void _addToOwnPath(String userId, Position position) {
    _ownPath.add(LocationPoint(
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed < 0 ? 0 : position.speed,
      heading: position.heading < 0 ? 0 : position.heading,
      updatedAt: DateTime.now(),
    ));
    if (!isRecording && _ownPath.length > SupabaseConfig.pathHistoryLength) {
      _ownPath.removeAt(0);
    }
  }

  Future<void> _upload(
    String userId,
    Position position, {
    bool writeHistory = true,
  }) async {
    final roomId = _recordingRoomId;
    final sessionId = _recordingSessionId;
    final point = LocationPoint(
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed < 0 ? 0 : position.speed,
      heading: position.heading < 0 ? 0 : position.heading,
      accuracy: position.accuracy,
      isOnline: true,
      updatedAt: DateTime.now(),
      roomId: roomId,
      sessionId: sessionId,
    );

    final tasks = <Future<void>>[SupabaseService.upsertLocation(point)];
    if (roomId != null && sessionId != null && writeHistory) {
      _recordDistance(position);
      tasks.add(SupabaseService.insertLocationHistory(point));
    }
    await Future.wait(tasks);
  }

  Future<void> _safeUpload(
    String userId,
    Position position, {
    bool force = false,
    bool writeHistory = true,
  }) async {
    if (!force && !_shouldUploadNow(position)) return;

    try {
      _lastUploadAt = DateTime.now();
      await _upload(userId, position, writeHistory: writeHistory);
    } catch (error) {
      debugPrint('Location upload failed: $error');
    }
  }

  bool _shouldUploadNow(Position position) {
    final last = _lastUploadAt;
    if (last == null) return true;
    final uploadInterval =
        SupabaseConfig.locationUploadIntervalForSpeed(position.speed);
    return DateTime.now().difference(last) >= uploadInterval;
  }

  void _recordDistance(Position position) {
    final previous = _lastRecordedPosition;
    if (previous != null) {
      _recordingDistanceMeters += LocationService.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
    }
    _lastRecordedPosition = position;
  }

  Future<void> stopTracking(String userId) async {
    await LocationService.stopTracking();
    _recordingUploadTimer?.cancel();
    _recordingUploadTimer = null;
    _isTracking = false;

    if (_currentPosition != null) {
      await SupabaseService.upsertLocation(LocationPoint(
        userId: userId,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        isOnline: false,
        updatedAt: DateTime.now(),
        roomId: null,
        sessionId: null,
      ));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingUploadTimer?.cancel();
    super.dispose();
  }
}
