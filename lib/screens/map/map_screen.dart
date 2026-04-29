import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/location_point.dart';
import '../../models/user_profile.dart';
import '../../services/facetime_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/friend_marker.dart';
import '../../widgets/speed_display.dart';
import '../../widgets/friend_info_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  bool _followMe = true;
  bool _initialized = false;

  static const _pathColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFE66D),
    Color(0xFF4ECDC4),
    Color(0xFFA8E6CF),
    Color(0xFFFF8B94),
    Color(0xFFB5EAD7),
    Color(0xFFC7CEEA),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    final locationProv = context.read<LocationProvider>();
    final friendsProv = context.read<FriendsProvider>();
    final roomsProv = context.read<RoomsProvider>();
    final settings = context.read<SettingsProvider>();

    await settings.load();

    if (auth.profile == null) {
      await auth.reloadProfile();
    }

    if (!mounted) return;

    if (auth.profile == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await friendsProv.initialize(auth.profile!.id);
    await roomsProv.initialize(auth.profile!.id);

    final ok = await locationProv.startTracking(
      auth.profile!.id,
      sharingEnabled: auth.profile!.isSharingLocation,
    );

    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 권한이 필요합니다. 설정에서 허용해주세요.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
    if (mounted) setState(() => _initialized = true);
  }

  void _onLocationChanged(LatLng pos) {
    if (_followMe) {
      _mapController.move(pos, _mapController.camera.zoom);
    }
    final settings = context.read<SettingsProvider>();
    context.read<FriendsProvider>().checkProximity(
          pos.latitude,
          pos.longitude,
          threshold: SupabaseConfig.proximityThresholdMeters,
          notificationsEnabled: settings.notificationsEnabled,
        );
  }

  // 모든 친구 + 내 위치가 다 보이도록 지도 줌 맞춤
  void _fitAllFriends() {
    final locProv = context.read<LocationProvider>();
    final friendsProv = context.read<FriendsProvider>();
    final roomsProv = context.read<RoomsProvider>();
    final myUserId = context.read<AuthProvider>().profile?.id;
    final roomLocations = roomsProv.memberLocations.values
        .where((l) => l.isActive && l.userId != myUserId)
        .map((l) => l.latLng);

    final points = <LatLng>[
      if (locProv.currentLatLng != null) locProv.currentLatLng!,
      ...roomLocations,
      ...friendsProv.friendLocations.values
          .where((l) => l.isActive)
          .map((l) => l.latLng),
    ];

    if (points.length < 2) {
      // 친구가 없으면 내 위치로만 이동
      if (locProv.currentLatLng != null) {
        setState(() => _followMe = true);
        _mapController.move(locProv.currentLatLng!, 15);
      }
      return;
    }

    setState(() => _followMe = false);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  Future<void> _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.profile != null) {
      context.read<FriendsProvider>().refresh(auth.profile!.id);
      context.read<RoomsProvider>().loadRooms(auth.profile!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = context.watch<AuthProvider>().profile;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          _buildMap(myProfile),
          _buildTopBar(),
          _buildSpeedWidget(),
          _buildRightButtons(),
          _buildBottomBar(),
          if (!_initialized) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF0A0E1A),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      ),
    );
  }

  // ─── Map ─────────────────────────────────────────────────────────────────

  Widget _buildMap(UserProfile? myProfile) {
    return Consumer3<LocationProvider, FriendsProvider, RoomsProvider>(
      builder: (ctx, locProv, friendsProv, roomsProv, _) {
        final myPos = locProv.currentLatLng;
        final myUserId = context.read<AuthProvider>().profile?.id;
        if (myPos != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onLocationChanged(myPos));
        }

        final center = myPos ?? const LatLng(37.5665, 126.9780);

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16.5,
            maxZoom: 19,
            minZoom: 5,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) setState(() => _followMe = false);
            },
          ),
          children: [
            // 다크 타일
            TileLayer(
              urlTemplate:
                  'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
              userAgentPackageName: 'com.mokky.friendTracker',
              maxNativeZoom: 19,
            ),

            // 친구 이동 경로
            PolylineLayer(
              polylines: [
                ..._buildFriendPolylines(friendsProv),
                ..._buildRoomPolylines(roomsProv, myUserId),
              ],
            ),

            // 내 이동 경로 (흰색 반투명)
            if (locProv.ownPath.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: locProv.ownPath
                        .map((p) => LatLng(p.latitude, p.longitude))
                        .toList(),
                    color: Colors.white.withOpacity(0.35),
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),

            // 친구 마커
            MarkerLayer(
              markers: [
                ..._buildFriendMarkers(friendsProv, myPos),
                ..._buildRoomMarkers(roomsProv, myUserId),
              ],
            ),

            // 내 위치
            if (myPos != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: myPos,
                    radius: _accuracyRadius(locProv),
                    useRadiusInMeter: true,
                    color: const Color(0xFF4ECDC4).withOpacity(0.08),
                    borderColor: const Color(0xFF4ECDC4).withOpacity(0.3),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: myPos,
                    width: 92,
                    height: 112,
                    child: _MyLocationMarker(
                      heading: locProv.currentHeading,
                      profile: myProfile,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  double _accuracyRadius(LocationProvider p) {
    final accuracy = p.currentPosition?.accuracy ?? 50;
    return accuracy.clamp(10, 200).toDouble();
  }

  List<Polyline> _buildFriendPolylines(FriendsProvider p) {
    int i = 0;
    return p.friendPaths.entries
        .where((e) =>
            e.value.length >= 2 &&
            (p.friendLocations[e.key]?.isActive ?? false))
        .map((entry) {
      final color = _pathColors[i++ % _pathColors.length];
      return Polyline(
        points:
            entry.value.map((pt) => LatLng(pt.latitude, pt.longitude)).toList(),
        color: color.withOpacity(0.65),
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      );
    }).toList();
  }

  List<Marker> _buildFriendMarkers(FriendsProvider p, LatLng? myPos) {
    int colorIdx = 0;

    return p.friendLocations.entries
        .where((entry) => entry.value.isActive)
        .map((entry) {
      final friendId = entry.key;
      final loc = entry.value;
      final profile = p.getFriendProfile(friendId);
      final color = _pathColors[colorIdx++ % _pathColors.length];
      final distance = myPos == null
          ? null
          : LocationService.distanceBetween(
              myPos.latitude,
              myPos.longitude,
              loc.latitude,
              loc.longitude,
            );
      final isNearby = distance != null &&
          distance <= SupabaseConfig.proximityThresholdMeters;

      return Marker(
        point: loc.latLng,
        width: 96,
        height: isNearby ? 128 : 104,
        child: GestureDetector(
          onTap: () => _openFriendSheet(profile, loc),
          child: FriendMarkerWidget(
            profile: profile,
            location: loc,
            accentColor: color,
            showWave: isNearby,
            onWaveTap: profile == null || distance == null
                ? null
                : () => _sendGreeting(profile, distance),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _sendGreeting(
    UserProfile recipientProfile,
    double distanceMeters,
  ) async {
    final senderProfile = context.read<AuthProvider>().profile;
    if (senderProfile == null) return;

    try {
      await context.read<FriendsProvider>().sendGreeting(
            senderProfile: senderProfile,
            recipientProfile: recipientProfile,
            distanceMeters: distanceMeters,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인사를 보내지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  List<Polyline> _buildRoomPolylines(RoomsProvider p, String? myUserId) {
    int i = 0;
    return p.memberPaths.entries
        .where((e) =>
            e.key != myUserId &&
            e.value.length >= 2 &&
            (p.memberLocations[e.key]?.isActive ?? false))
        .map((entry) {
      final color = _pathColors[(i++ + 2) % _pathColors.length];
      return Polyline(
        points: entry.value.map((pt) => pt.latLng).toList(),
        color: color.withOpacity(0.8),
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      );
    }).toList();
  }

  List<Marker> _buildRoomMarkers(RoomsProvider p, String? myUserId) {
    int colorIdx = 0;
    return p.memberLocations.entries
        .where((entry) => entry.key != myUserId && entry.value.isActive)
        .map((entry) {
      final profile = p.memberProfile(entry.key);
      final color = _pathColors[(colorIdx++ + 2) % _pathColors.length];
      return Marker(
        point: entry.value.latLng,
        width: 84,
        height: 100,
        child: GestureDetector(
          onTap: () => _openFriendSheet(profile, entry.value),
          child: FriendMarkerWidget(
            profile: profile,
            location: entry.value,
            accentColor: color,
          ),
        ),
      );
    }).toList();
  }

  void _openFriendSheet(UserProfile? profile, LocationPoint loc) {
    if (profile == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FriendInfoSheet(
        profile: profile,
        location: loc,
        onFaceTimeVideo: () => _facetime(profile, audio: false),
        onFaceTimeAudio: () => _facetime(profile, audio: true),
      ),
    );
  }

  Future<void> _facetime(UserProfile profile, {required bool audio}) async {
    final contact = FaceTimeService.getContact(profile.phone, profile.email);
    if (contact == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연락처 정보가 없습니다')),
        );
      }
      return;
    }

    final ok = audio
        ? await FaceTimeService.audioCall(contact)
        : await FaceTimeService.videoCall(contact);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FaceTime을 실행할 수 없습니다 (iOS 전용)')),
      );
    }
  }

  // ─── Overlay UI ──────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const _GlassChip(
              child: AppLogo(size: 26, borderRadius: 7),
            ),
            const Spacer(),
            _CircleButton(
              icon: Icons.people_outline,
              onTap: () => _navigateAndRefresh('/friends'),
              badge: context.watch<FriendsProvider>().pendingRequests.length,
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.route,
              onTap: () => _navigateAndRefresh('/rooms'),
              badge: context.watch<RoomsProvider>().isRecording ? 1 : 0,
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.person_outline,
              onTap: () async {
                await Navigator.pushNamed(context, '/profile');
                if (!mounted) return;
                // 프로필에서 위치 공유 설정 변경 시 반영
                final auth = context.read<AuthProvider>();
                final locProv = context.read<LocationProvider>();
                if (auth.profile != null) {
                  await locProv.setLocationSharing(
                    auth.profile!.isSharingLocation,
                    userId: auth.profile!.id,
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.settings_outlined,
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedWidget() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 80,
      child: Consumer2<LocationProvider, SettingsProvider>(
        builder: (_, location, settings, __) => SpeedDisplay(
          speedKmh: location.currentSpeedKmh,
          speedUnit: settings.speedUnit,
        ),
      ),
    );
  }

  // 우측 중앙 버튼들 (fit all)
  Widget _buildRightButtons() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 180,
      child: _CircleButton(
        icon: Icons.fit_screen_outlined,
        onTap: _fitAllFriends,
        tooltip: '모두 보기',
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF0A0E1A),
              const Color(0xFF0A0E1A).withOpacity(0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            _buildRecenterButton(),
            const SizedBox(width: 12),
            Consumer<FriendsProvider>(
              builder: (_, fp, __) => _GlassChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fp.onlineFriendCount > 0
                            ? const Color(0xFF4ECDC4)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '온라인 ${fp.onlineFriendCount}명',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            // 위치 미공유 표시
            Consumer<LocationProvider>(
              builder: (_, lp, __) => lp.isSharingLocation
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _GlassChip(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off,
                                color: Colors.orange.shade400, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '위치 비공개',
                              style: TextStyle(
                                  color: Colors.orange.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _followMe = true);
        final pos = context.read<LocationProvider>().currentLatLng;
        if (pos != null) _mapController.move(pos, 16.5);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _followMe
              ? const Color(0xFF4ECDC4).withOpacity(0.15)
              : const Color(0xFF1A2332).withOpacity(0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _followMe
                ? const Color(0xFF4ECDC4)
                : const Color(0xFF4ECDC4).withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _followMe ? Icons.my_location : Icons.location_searching,
              color: _followMe ? const Color(0xFF4ECDC4) : Colors.white54,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _followMe ? '내 위치 추적 중' : '내 위치로',
              style: TextStyle(
                color: _followMe ? const Color(0xFF4ECDC4) : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small Shared Widgets ─────────────────────────────────────────────────────

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.25)),
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332).withOpacity(0.9),
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B), shape: BoxShape.circle),
                child: Center(
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}

// ─── My Location Marker ──────────────────────────────────────────────────────

class _MyLocationMarker extends StatefulWidget {
  const _MyLocationMarker({required this.heading, required this.profile});

  final double heading;
  final UserProfile? profile;

  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.22)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 58 * _pulse.value,
                height: 58 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4ECDC4).withOpacity(0.12),
                ),
              ),
              Transform.rotate(
                angle: widget.heading * (3.14159265 / 180),
                child: CustomPaint(
                  size: const Size(38, 38),
                  painter: _HeadingPainter(),
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ECDC4).withOpacity(0.7),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(child: _avatar(profile)),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A).withOpacity(0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            profile?.name ?? '나',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _avatar(UserProfile? profile) {
    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _defaultAvatar(profile),
        errorWidget: (_, __, ___) => _defaultAvatar(profile),
      );
    }
    return _defaultAvatar(profile);
  }

  Widget _defaultAvatar(UserProfile? profile) {
    return Container(
      color: const Color(0xFF4ECDC4),
      alignment: Alignment.center,
      child: Text(
        (profile?.name ?? '나').substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF0A0E1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _HeadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4ECDC4).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * 0.35, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.45)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
