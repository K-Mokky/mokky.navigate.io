import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/friends_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/rooms/rooms_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';

class FriendTrackerApp extends StatelessWidget {
  const FriendTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '친추',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4ECDC4),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A2332),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        useMaterial3: true,
      ),
      builder: (context, child) => _InAppNoticeOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/map': (_) => const MapScreen(),
        '/friends': (_) => const FriendsScreen(),
        '/rooms': (_) => const RoomsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

class _InAppNoticeOverlay extends StatefulWidget {
  const _InAppNoticeOverlay({required this.child});

  final Widget child;

  @override
  State<_InAppNoticeOverlay> createState() => _InAppNoticeOverlayState();
}

class _InAppNoticeOverlayState extends State<_InAppNoticeOverlay> {
  String? _lastNoticeId;
  String? _noticeText;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _show(String message) {
    _noticeTimer?.cancel();
    setState(() => _noticeText = message);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _noticeText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsProvider>(
      builder: (context, friends, _) {
        final notice = friends.latestNotice;
        if (notice != null && notice.id != _lastNoticeId) {
          _lastNoticeId = notice.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _show(notice.message);
          });
        }

        return Stack(
          children: [
            widget.child,
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 12,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _noticeText == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(_noticeText),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2332).withOpacity(0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF4ECDC4).withOpacity(0.45),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.waving_hand,
                                color: Color(0xFFFFE66D),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _noticeText!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
