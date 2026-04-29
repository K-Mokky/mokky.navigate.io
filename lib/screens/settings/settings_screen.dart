import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white54, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('설정',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<SettingsProvider>(
        builder: (_, settings, __) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionLabel('알림'),
            const SizedBox(height: 10),

            // 근접 알림 ON/OFF
            _SettingsTile(
              title: '근접 알림',
              subtitle: settings.notificationsEnabled
                  ? '친구가 근처에 오면 알림을 받습니다'
                  : '근접 알림이 꺼져 있습니다',
              trailing: Switch(
                value: settings.notificationsEnabled,
                activeColor: const Color(0xFF4ECDC4),
                onChanged: settings.setNotificationsEnabled,
              ),
            ),

            const SizedBox(height: 14),
            const _SettingsTile(
              title: '근접 알림 기준',
              subtitle: '친구가 300m 이내에 들어오면 알림을 보내고, 5km 이상 멀어진 뒤 다시 알립니다',
              trailing: Icon(Icons.radar, color: Color(0xFF4ECDC4), size: 20),
            ),

            const SizedBox(height: 32),
            const _SectionLabel('지도'),
            const SizedBox(height: 10),

            const _SettingsTile(
              title: '경로 색상',
              subtitle: '각 친구마다 다른 색상으로 이동 경로 표시',
              trailing:
                  Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 20),
            ),

            const SizedBox(height: 14),
            _SettingsTile(
              title: '속도 단위',
              subtitle: '현재 속도를 ${settings.speedUnit.label}로 표시합니다',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<SpeedUnit>(
                  value: settings.speedUnit,
                  dropdownColor: const Color(0xFF1A2332),
                  iconEnabledColor: const Color(0xFF4ECDC4),
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  items: SpeedUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label),
                        ),
                      )
                      .toList(),
                  onChanged: (unit) {
                    if (unit != null) settings.setSpeedUnit(unit);
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),
            const _SectionLabel('앱 정보'),
            const SizedBox(height: 10),
            const _SettingsTile(
              title: '친추',
              subtitle: '버전 1.0.0',
              trailing: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
