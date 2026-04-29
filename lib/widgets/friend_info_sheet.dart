import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/location_point.dart';
import '../providers/settings_provider.dart';

class FriendInfoSheet extends StatelessWidget {
  const FriendInfoSheet({
    super.key,
    required this.profile,
    required this.location,
    required this.onFaceTimeVideo,
    required this.onFaceTimeAudio,
  });

  final UserProfile profile;
  final LocationPoint location;
  final VoidCallback onFaceTimeVideo;
  final VoidCallback onFaceTimeAudio;

  @override
  Widget build(BuildContext context) {
    final hasContact = (profile.phone?.isNotEmpty ?? false) ||
        (profile.email?.isNotEmpty ?? false);
    final speedUnit = context.watch<SettingsProvider>().speedUnit;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 (아바타 + 기본 정보)
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF4ECDC4), width: 2),
                          color: const Color(0xFF0A0E1A),
                        ),
                        child: ClipOval(
                          child: Center(
                            child: Text(
                              profile.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF4ECDC4),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '@${profile.username}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4ECDC4),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  location.movementLabel,
                                  style: const TextStyle(
                                      color: Color(0xFF4ECDC4), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 속도 / 방향 스탯
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.speed,
                        label: '속도',
                        value: speedUnit.formatFromKmh(location.speedKmh),
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: Icons.explore_outlined,
                        label: '방향',
                        value: _headingLabel(location.heading),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // FaceTime 버튼
                  if (hasContact) ...[
                    const Text(
                      'FaceTime',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: CupertinoIcons.video_camera_solid,
                            label: '영상통화',
                            color: const Color(0xFF4ECDC4),
                            onTap: () {
                              Navigator.pop(context);
                              onFaceTimeVideo();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: CupertinoIcons.phone_solid,
                            label: '음성통화',
                            color: const Color(0xFFA8E6CF),
                            onTap: () {
                              Navigator.pop(context);
                              onFaceTimeAudio();
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white24, size: 16),
                          SizedBox(width: 8),
                          Text(
                            '이 친구는 연락처 정보를 등록하지 않았습니다',
                            style:
                                TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headingLabel(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    final idx = ((heading + 22.5) / 45).floor() % 8;
    return '${directions[idx]} ${heading.round()}°';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4ECDC4), size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
