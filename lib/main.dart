import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/rooms_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'widgets/app_logo.dart';

void main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!SupabaseConfig.isConfigured) {
      runApp(
        const _StartupStatusApp(
          title: 'Supabase 설정이 필요합니다',
          message: 'flutter run --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=... 형식으로 실행해주세요. '
              '프로젝트 URL과 publishable key는 소스에 커밋하지 않습니다.',
        ),
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      await NotificationService.initialize();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app startup',
          context: ErrorDescription('while initializing Supabase or services'),
        ),
      );
      runApp(
        const _StartupStatusApp(
          title: '앱을 시작하지 못했습니다',
          message: '초기화 중 문제가 발생했습니다. '
              '잠시 후 다시 접속하거나 새로고침해주세요.',
        ),
      );
      return;
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
          ChangeNotifierProvider(create: (_) => RoomsProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const FriendTrackerApp(),
      ),
    );
  }, (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app runtime',
        context: ErrorDescription('from the guarded application zone'),
      ),
    );
  });
}

class _StartupStatusApp extends StatelessWidget {
  const _StartupStatusApp({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 72, showShadow: true),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
