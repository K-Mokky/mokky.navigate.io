import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _emailCtrl,
      _usernameCtrl,
      _nameCtrl,
      _phoneCtrl,
      _pwCtrl,
      _pwConfirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _pwCtrl.text,
      username: _usernameCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/map');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? '회원가입에 실패했습니다')));
    }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '회원가입',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('친추에 오신 것을 환영합니다',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
                const SizedBox(height: 32),
                AuthField(
                  controller: _emailCtrl,
                  label: '이메일 *',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : '올바른 이메일을 입력하세요',
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _usernameCtrl,
                  label: '아이디 (영문, 숫자, _) *',
                  icon: Icons.alternate_email,
                  validator: (v) {
                    if ((v ?? '').length < 3) return '3자 이상 입력하세요';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v!)) {
                      return '영문, 숫자, _만 사용 가능합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _nameCtrl,
                  label: '닉네임',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _phoneCtrl,
                  label: '전화번호 (FaceTime용)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _pwCtrl,
                  label: '비밀번호 *',
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  validator: (v) =>
                      (v ?? '').length >= 6 ? null : '6자 이상 입력하세요',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 12),
                AuthField(
                  controller: _pwConfirmCtrl,
                  label: '비밀번호 확인 *',
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  validator: (v) =>
                      v == _pwCtrl.text ? null : '비밀번호가 일치하지 않습니다',
                ),
                const SizedBox(height: 32),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => PrimaryButton(
                    label: '가입하기',
                    isLoading: auth.isLoading,
                    onTap: _signUp,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
