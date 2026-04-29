import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => SupabaseService.currentUser != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    SupabaseService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _loadProfile();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _profile = null;
        notifyListeners();
      }
    });
    if (isAuthenticated) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    _profile = await SupabaseService.getProfile(userId);
    notifyListeners();
  }

  Future<void> reloadProfile() => _loadProfile();

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService.signIn(email: email, password: password);
      await _loadProfile();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = '로그인에 실패했습니다. 다시 시도해주세요.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        phone: phone,
      );
      if (response.session == null) {
        _error = '가입 확인 이메일을 확인한 뒤 로그인해주세요.';
        return false;
      }
      await _loadProfile();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = '회원가입에 실패했습니다. 다시 시도해주세요.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await SupabaseService.updateProfile(updates);
    await _loadProfile();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
  }
}
