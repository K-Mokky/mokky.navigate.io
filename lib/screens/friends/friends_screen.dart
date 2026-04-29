import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../models/location_point.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/location_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white54, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('친구',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF4ECDC4),
          labelColor: const Color(0xFF4ECDC4),
          unselectedLabelColor: Colors.white38,
          tabs: [
            const Tab(text: '친구 목록'),
            Tab(
              child: Consumer<FriendsProvider>(
                builder: (_, fp, __) {
                  final count = fp.pendingRequests.length;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('요청'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: '친구 추가'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FriendListTab(),
          _PendingRequestsTab(),
          _SearchTab(),
        ],
      ),
    );
  }
}

// ─── 친구 목록 ────────────────────────────────────────────────────────────────

class _FriendListTab extends StatelessWidget {
  const _FriendListTab();

  @override
  Widget build(BuildContext context) {
    return Consumer3<FriendsProvider, AuthProvider, LocationProvider>(
      builder: (_, fp, auth, locProv, __) {
        final friends = fp.friends;
        final myId = auth.profile?.id ?? '';
        final myPos = locProv.currentPosition;

        if (fp.loading && friends.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)));
        }

        if (friends.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            text: '아직 친구가 없습니다\n친구 추가 탭에서 찾아보세요',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final f = friends[i];
            final profile = f.friendProfile(myId);
            final LocationPoint? loc =
                profile != null ? fp.friendLocations[profile.id] : null;

            // 내 위치가 있으면 거리 계산
            double? distMeters;
            if (myPos != null && loc != null && loc.isActive) {
              distMeters = LocationService.distanceBetween(
                myPos.latitude,
                myPos.longitude,
                loc.latitude,
                loc.longitude,
              );
            }

            return _FriendTile(
              profile: profile,
              location: loc,
              distanceMeters: distMeters,
              onRemove: () async {
                final confirm = await _confirmDialog(
                    context, '친구 삭제', '${profile?.name ?? '이 친구'}를 삭제하시겠습니까?');
                if (confirm == true && auth.profile != null) {
                  await fp.removeFriend(f.id, auth.profile!.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    this.profile,
    this.location,
    this.distanceMeters,
    this.onRemove,
  });

  final UserProfile? profile;
  final LocationPoint? location;
  final double? distanceMeters;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isOnline = location?.isActive == true;
    final speedKmh = location?.speedKmh ?? 0.0;
    final speedUnit = context.watch<SettingsProvider>().speedUnit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOnline
                ? const Color(0xFF4ECDC4).withOpacity(0.3)
                : Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // 아바타 + 온라인 도트
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF0A0E1A),
                child: Text(
                  (profile?.name ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF4ECDC4)
                        : Colors.grey.shade700,
                    border:
                        Border.all(color: const Color(0xFF1A2332), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // 이름 / 아이디 / 상태
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? '알 수 없음',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                Text('@${profile?.username ?? '-'}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 2),
                if (isOnline)
                  Text(
                    speedKmh < 1
                        ? '정지 중'
                        : '${speedUnit.formatFromKmh(speedKmh)} 이동 중',
                    style:
                        const TextStyle(color: Color(0xFF4ECDC4), fontSize: 11),
                  )
                else if (location != null)
                  Text(
                    '마지막: ${_timeAgo(location!.updatedAt)}',
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
              ],
            ),
          ),

          // 거리 뱃지
          if (distanceMeters != null)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.4)),
              ),
              child: Text(
                _formatDistance(distanceMeters!),
                style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),

          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.person_remove_outlined,
                  color: Colors.white24, size: 20),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ─── 친구 요청 ────────────────────────────────────────────────────────────────

class _PendingRequestsTab extends StatelessWidget {
  const _PendingRequestsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<FriendsProvider, AuthProvider>(
      builder: (_, fp, auth, __) {
        final requests = fp.pendingRequests;

        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.mark_email_read_outlined,
            text: '대기 중인 친구 요청이 없습니다',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final req = requests[i];
            return _RequestTile(
              sender: req.requesterProfile,
              onAccept: () async {
                if (auth.profile != null) {
                  await fp.respondToRequest(req.id, true, auth.profile!.id);
                }
              },
              onReject: () async {
                if (auth.profile != null) {
                  await fp.respondToRequest(req.id, false, auth.profile!.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(
      {this.sender, required this.onAccept, required this.onReject});

  final UserProfile? sender;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF0A0E1A),
            child: Text(
              (sender?.name ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sender?.name ?? '알 수 없음',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text('@${sender?.username ?? '-'}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: Color(0xFF4ECDC4), size: 28),
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined,
                color: Color(0xFFFF6B6B), size: 28),
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}

// ─── 친구 검색 ────────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _ctrl = TextEditingController();
  List<UserProfile> _results = [];
  bool _searching = false;
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await context.read<FriendsProvider>().searchUsers(q);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FriendsProvider>();
    final currentUserId = context.watch<AuthProvider>().profile?.id ?? '';
    final existingFriendIds = fp.friends
        .map((friendship) => friendship.friendId(currentUserId))
        .toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '아이디로 검색...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF4ECDC4), size: 20),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF4ECDC4)),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward,
                          color: Color(0xFF4ECDC4), size: 20),
                      onPressed: _search,
                    ),
              filled: true,
              fillColor: const Color(0xFF1A2332),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF4ECDC4), width: 1.5),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? const _EmptyState(
                  icon: Icons.person_search_outlined,
                  text: '아이디로 친구를 검색하세요',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final user = _results[i];
                    final isAlreadyFriend = existingFriendIds.contains(user.id);
                    final sent =
                        _sentRequests.contains(user.id) || isAlreadyFriend;
                    return _SearchResultTile(
                      user: user,
                      requestSent: sent,
                      requestLabel: isAlreadyFriend ? '친구' : null,
                      onAdd: sent
                          ? null
                          : () async {
                              final friendsProvider =
                                  context.read<FriendsProvider>();
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await friendsProvider
                                    .sendFriendRequest(user.id);
                                if (mounted) {
                                  setState(() => _sentRequests.add(user.id));
                                  messenger.showSnackBar(SnackBar(
                                    content:
                                        Text('${user.name}에게 친구 요청을 보냈습니다'),
                                  ));
                                }
                              } catch (_) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('이미 요청했거나 친구 요청을 보낼 수 없습니다'),
                                    ),
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.user,
    required this.requestSent,
    this.requestLabel,
    this.onAdd,
  });

  final UserProfile user;
  final bool requestSent;
  final String? requestLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF0A0E1A),
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text('@${user.username}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: Icon(
              requestSent ? Icons.check : Icons.person_add_outlined,
              size: 16,
              color: requestSent ? Colors.white38 : const Color(0xFF4ECDC4),
            ),
            label: Text(
              requestSent ? requestLabel ?? '요청 완료' : '추가',
              style: TextStyle(
                color: requestSent ? Colors.white38 : const Color(0xFF4ECDC4),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmDialog(
    BuildContext context, String title, String content) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A2332),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(content, style: const TextStyle(color: Colors.white60)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소', style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('확인', style: TextStyle(color: Color(0xFFFF6B6B))),
        ),
      ],
    ),
  );
}
