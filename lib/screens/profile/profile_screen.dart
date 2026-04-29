import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/auth_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _sharingLocation = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _emailCtrl = TextEditingController(text: profile?.email ?? '');
    _nameCtrl = TextEditingController(text: profile?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
    _sharingLocation = profile?.isSharingLocation ?? true;
    _avatarUrl = profile?.avatarUrl;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;

    final auth = context.read<AuthProvider>();
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (!mounted || image == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await image.readAsBytes();
      final extension = _imageExtension(image.name);
      final avatarUrl = await SupabaseService.uploadAvatar(
        bytes: bytes,
        extension: extension,
        contentType: _contentType(extension),
      );
      await auth.updateProfile({
        'avatar_url': avatarUrl,
      });
      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 저장됐습니다')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진 저장에 실패했습니다')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _imageExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    final userId = auth.profile?.id;

    try {
      // 위치 공유를 끄는 경우에는 프로필 비공개 전 온라인 상태를 먼저 내려
      // 기존 구독 중인 친구 화면에서도 마커가 즉시 사라지도록 한다.
      if (!_sharingLocation) {
        await locationProvider.setLocationSharing(false, userId: userId);
      }

      await auth.updateProfile({
        'display_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'is_sharing_location': _sharingLocation,
      });

      if (!mounted) return;

      // 켜는 경우에는 프로필 공개 후 현재 위치를 다시 업로드한다.
      if (_sharingLocation) {
        await locationProvider.setLocationSharing(true, userId: userId);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장됐습니다')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 저장에 실패했습니다')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text('정말 로그아웃 하시겠습니까?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('로그아웃', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final locProv = context.read<LocationProvider>();
    final userId = auth.profile?.id;

    if (userId != null) await locProv.stopTracking(userId);
    await auth.signOut();

    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

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
        title: const Text('프로필',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4ECDC4)),
                  )
                : const Text('저장',
                    style: TextStyle(
                        color: Color(0xFF4ECDC4), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아바타
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF4ECDC4), width: 2.5),
                          color: const Color(0xFF1A2332),
                        ),
                        child: ClipOval(child: _buildAvatar(profile)),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF0A0E1A), width: 3),
                          ),
                          child: _isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0A0E1A),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Color(0xFF0A0E1A),
                                  size: 17,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '사진을 누르면 지도 아이콘으로 사용할 프로필 사진을 바꿀 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '@${profile?.username ?? ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),

              const SizedBox(height: 32),
              _sectionLabel('기본 정보'),
              const SizedBox(height: 12),

              // 이메일 (수정 불가)
              AuthField(
                controller: _emailCtrl,
                label: '이메일',
                icon: Icons.email_outlined,
                enabled: false,
              ),
              const SizedBox(height: 12),

              // 닉네임
              AuthField(
                controller: _nameCtrl,
                label: '닉네임',
                icon: Icons.person_outline,
                validator: (v) => (v ?? '').isNotEmpty ? null : '닉네임을 입력하세요',
              ),
              const SizedBox(height: 12),

              // 전화번호 (FaceTime용)
              AuthField(
                controller: _phoneCtrl,
                label: '전화번호 (FaceTime용)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '전화번호 또는 Apple ID 이메일을 입력하면 FaceTime 연결에 사용됩니다',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
              ),

              const SizedBox(height: 32),
              _sectionLabel('위치 공유'),
              const SizedBox(height: 12),

              // 위치 공유 토글
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _sharingLocation
                          ? const Color(0xFF4ECDC4).withOpacity(0.3)
                          : Colors.white.withOpacity(0.08)),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('위치 공유 활성화',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(
                    _sharingLocation
                        ? '친구들에게 내 위치가 표시됩니다'
                        : '친구들에게 내 위치가 표시되지 않습니다',
                    style: TextStyle(
                        color: _sharingLocation
                            ? const Color(0xFF4ECDC4)
                            : Colors.white38,
                        fontSize: 12),
                  ),
                  value: _sharingLocation,
                  activeColor: const Color(0xFF4ECDC4),
                  onChanged: (v) => setState(() => _sharingLocation = v),
                ),
              ),

              const SizedBox(height: 40),
              _sectionLabel('계정'),
              const SizedBox(height: 12),

              // 로그아웃
              GestureDetector(
                onTap: _signOut,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 20),
                      SizedBox(width: 12),
                      Text('로그아웃',
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
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

  Widget _buildAvatar(UserProfile? profile) {
    final url = _avatarUrl ?? profile?.avatarUrl;
    if (url is String && url.isNotEmpty) {
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
    return Center(
      child: Text(
        (profile?.name ?? '?').substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF4ECDC4),
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
