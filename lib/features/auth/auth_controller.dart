import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  const AuthState({
    this.email,
    this.displayName,
    this.isLoading = true,
  });

  final String? email;
  final String? displayName;
  final bool isLoading;

  bool get isLoggedIn => email != null && email!.isNotEmpty;

  AuthState copyWith({
    String? email,
    String? displayName,
    bool? isLoading,
    bool clearUser = false,
  }) {
    return AuthState(
      email: clearUser ? null : (email ?? this.email),
      displayName: clearUser ? null : (displayName ?? this.displayName),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      email: prefs.getString(_emailKey),
      displayName: prefs.getString(_nameKey),
      isLoading: false,
    );
  }

  Future<String?> login(String email, String password) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return '请输入有效邮箱';
    }
    if (password.length < 4) {
      return '密码至少 4 位';
    }
    final prefs = await SharedPreferences.getInstance();
    final name = trimmed.split('@').first;
    await prefs.setString(_emailKey, trimmed);
    await prefs.setString(_nameKey, name);
    state = state.copyWith(
      email: trimmed,
      displayName: name,
      isLoading: false,
    );
    return null;
  }

  Future<String?> register(String email, String password, String name) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return '请输入有效邮箱';
    }
    if (password.length < 4) {
      return '密码至少 4 位';
    }
    if (name.trim().isEmpty) {
      return '请输入昵称';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, trimmed);
    await prefs.setString(_nameKey, name.trim());
    state = state.copyWith(
      email: trimmed,
      displayName: name.trim(),
      isLoading: false,
    );
    return null;
  }

  Future<void> enterAsGuest() async {
    const email = 'guest@local';
    const name = '游客';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_nameKey, name);
    state = const AuthState(
      email: email,
      displayName: name,
      isLoading: false,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    state = state.copyWith(clearUser: true, isLoading: false);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
