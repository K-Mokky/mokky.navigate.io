import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/location_point.dart';
import '../providers/settings_provider.dart';

class FriendMarkerWidget extends StatelessWidget {
  const FriendMarkerWidget({
    super.key,
    this.profile,
    required this.location,
    required this.accentColor,
    this.showWave = false,
    this.onWaveTap,
  });

  final UserProfile? profile;
  final LocationPoint location;
  final Color accentColor;
  final bool showWave;
  final VoidCallback? onWaveTap;

  @override
  Widget build(BuildContext context) {
    final speedUnit = context.watch<SettingsProvider>().speedUnit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 속도 뱃지 (약 1km/h 이상일 때만 표시)
        if (location.speedKmh >= 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A).withOpacity(0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.7)),
            ),
            child: Text(
              speedUnit.formatFromKmh(location.speedKmh),
              style: TextStyle(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

        if (showWave) ...[
          _WaveButton(onTap: onWaveTap),
          const SizedBox(height: 2),
        ],

        // 아바타 + 글로우
        _AvatarBubble(
          avatar: _avatar,
          accentColor: accentColor,
          isOnline: location.isOnline,
        ),

        // 이름 라벨
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A).withOpacity(0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            profile?.name ?? '???',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget get _avatar {
    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _defaultIcon,
        errorWidget: (_, __, ___) => _defaultIcon,
      );
    }
    return _defaultIcon;
  }

  Widget get _defaultIcon => Center(
        child: Text(
          (profile?.name ?? '?').substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: accentColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.avatar,
    required this.accentColor,
    required this.isOnline,
  });

  final Widget avatar;
  final Color accentColor;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 글로우 링
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.45),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
        // 아바타 원
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.5),
            color: const Color(0xFF1A2332),
          ),
          child: ClipOval(child: avatar),
        ),
        // 온라인 인디케이터
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF4ECDC4) : Colors.grey.shade600,
              border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveButton extends StatefulWidget {
  const _WaveButton({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_WaveButton> createState() => _WaveButtonState();
}

class _WaveButtonState extends State<_WaveButton> {
  bool _pressed = false;

  Future<void> _handleTap() async {
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (mounted) setState(() => _pressed = false);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.78 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A).withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE66D), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFE66D).withOpacity(0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text('👋', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
