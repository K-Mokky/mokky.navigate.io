import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import '../../models/recording_room.dart';
import '../../models/recording_session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/rooms_provider.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await context.read<RoomsProvider>().loadRooms(userId);
  }

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
        title: const Text('기록 공유 방',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link, color: Color(0xFF4ECDC4)),
            onPressed: _showJoinDialog,
            tooltip: '링크/코드로 참여',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
            onPressed: _showCreateDialog,
            tooltip: '방 만들기',
          ),
        ],
      ),
      body: Consumer3<RoomsProvider, AuthProvider, LocationProvider>(
        builder: (_, rooms, auth, location, __) {
          final active = rooms.activeRoom;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (rooms.loading)
                const LinearProgressIndicator(color: Color(0xFF4ECDC4)),
              if (rooms.error != null) ...[
                const SizedBox(height: 10),
                Text(rooms.error!,
                    style: const TextStyle(color: Color(0xFFFF6B6B))),
              ],
              _HeaderCard(
                activeRoom: active,
                isRecording: rooms.isRecording,
                distanceMeters: location.recordingDistanceMeters,
                summary: rooms.lastSummary,
                onCopy: active == null ? null : () => _copyRoom(active),
                onStart: active == null || rooms.isRecording
                    ? null
                    : () => _startRecording(auth, rooms, location),
                onStop: rooms.isRecording
                    ? () => _stopRecording(auth, rooms, location)
                    : null,
              ),
              const SizedBox(height: 24),
              const _SectionTitle('내 기록방'),
              const SizedBox(height: 10),
              if (rooms.rooms.isEmpty)
                const _EmptyRooms()
              else
                ...rooms.rooms.map(
                  (room) => _RoomTile(
                    room: room,
                    selected: room.id == rooms.activeRoom?.id,
                    onTap: () => rooms.selectRoom(room),
                    onCopy: () => _copyRoom(room),
                  ),
                ),
              const SizedBox(height: 24),
              const _SectionTitle('현재 방 참가자'),
              const SizedBox(height: 10),
              if (rooms.members.isEmpty)
                const Text('참가자가 없습니다', style: TextStyle(color: Colors.white38))
              else
                ...rooms.members.map(
                  (member) => _MemberTile(
                    name: member.name,
                    username: member.username,
                    isRecording:
                        rooms.memberLocations[member.id]?.isActive == true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startRecording(
    AuthProvider auth,
    RoomsProvider rooms,
    LocationProvider location,
  ) async {
    final userId = auth.profile?.id;
    if (userId == null) return;
    final ok = await rooms.startRecording(
      userId: userId,
      locationProvider: location,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '기록을 시작했습니다' : '기록을 시작할 수 없습니다')),
    );
  }

  Future<void> _stopRecording(
    AuthProvider auth,
    RoomsProvider rooms,
    LocationProvider location,
  ) async {
    final userId = auth.profile?.id;
    if (userId == null) return;
    final summary = await rooms.stopRecording(
      userId: userId,
      locationProvider: location,
    );
    if (!mounted || summary == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('기록 종료', style: TextStyle(color: Colors.white)),
        content: Text(
          '총 이동 거리: ${_formatDistance(summary.totalDistanceMeters)}',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF4ECDC4))),
          ),
        ],
      ),
    );
  }

  Future<void> _copyRoom(RecordingRoom room) async {
    await Clipboard.setData(
      ClipboardData(text: '${room.shareLink}\n초대 코드: ${room.inviteCode}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('방 링크와 코드가 복사됐습니다')),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController(text: '주행 기록방');
    var retentionDays = SupabaseConfig.defaultRoomRetentionDays.toDouble();
    final result = await showDialog<({String name, int days})>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          title: const Text('기록방 만들기', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '방 이름',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              Text('보관 기간: ${retentionDays.round()}일',
                  style: const TextStyle(color: Color(0xFF4ECDC4))),
              Slider(
                value: retentionDays,
                min: 1,
                max: SupabaseConfig.maxRoomRetentionDays.toDouble(),
                divisions: SupabaseConfig.maxRoomRetentionDays - 1,
                activeColor: const Color(0xFF4ECDC4),
                onChanged: (value) => setState(() => retentionDays = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                (name: nameCtrl.text, days: retentionDays.round()),
              ),
              child:
                  const Text('생성', style: TextStyle(color: Color(0xFF4ECDC4))),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (result == null || !mounted) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;
    await context.read<RoomsProvider>().createRoom(
          userId: userId,
          name: result.name,
          retentionDays: result.days,
        );
  }

  Future<void> _showJoinDialog() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('기록방 참여', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: '초대 코드 또는 radar://room/... 링크',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('참여', style: TextStyle(color: Color(0xFF4ECDC4))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || !mounted) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;
    await context.read<RoomsProvider>().joinRoom(_extractCode(code), userId);
  }

  String _extractCode(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'radar' && uri.host == 'room') {
      return uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    }
    return trimmed.replaceAll('초대 코드:', '').trim();
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.activeRoom,
    required this.isRecording,
    required this.distanceMeters,
    required this.summary,
    this.onCopy,
    this.onStart,
    this.onStop,
  });

  final RecordingRoom? activeRoom;
  final bool isRecording;
  final double distanceMeters;
  final RecordingSummary? summary;
  final VoidCallback? onCopy;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final room = activeRoom;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room == null ? '활성 기록방 없음' : room.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          if (room != null)
            Text(
              '초대 코드 ${room.inviteCode} · ${_date(room.expiresAt)}까지 보관',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            )
          else
            const Text('방을 만들거나 링크/코드로 참여하세요',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          if (isRecording)
            Text('기록 중 · ${_formatDistance(distanceMeters)} 이동',
                style: const TextStyle(color: Color(0xFF4ECDC4)))
          else if (summary != null)
            Text(
              '마지막 기록: ${_formatDistance(summary!.totalDistanceMeters)}',
              style: const TextStyle(color: Color(0xFF4ECDC4)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRecording ? onStop : onStart,
                  icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
                  label: Text(isRecording ? '기록 종료' : '기록 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF4ECDC4),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onCopy,
                icon: const Icon(Icons.ios_share),
                tooltip: '방 링크 복사',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _date(DateTime date) => DateFormat('M/d HH:mm').format(date.toLocal());

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  final RecordingRoom room;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? const Color(0xFF4ECDC4)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(room.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('코드 ${room.inviteCode}',
            style: const TextStyle(color: Colors.white38)),
        trailing: IconButton(
          icon: const Icon(Icons.copy, color: Color(0xFF4ECDC4)),
          onPressed: onCopy,
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.username,
    required this.isRecording,
  });

  final String name;
  final String username;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A2332),
        child: Text(name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Color(0xFF4ECDC4))),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle:
          Text('@$username', style: const TextStyle(color: Colors.white38)),
      trailing: Text(
        isRecording ? '기록 중' : '대기',
        style: TextStyle(
          color: isRecording ? const Color(0xFF4ECDC4) : Colors.white38,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '아직 참여 중인 기록방이 없습니다. + 버튼으로 만들거나 링크로 참여하세요.',
        style: TextStyle(color: Colors.white38, height: 1.5),
      ),
    );
  }
}
