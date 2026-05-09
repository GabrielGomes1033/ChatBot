import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

class AuthSessionService {
  static const _sessionKey = 'nova.auth.session.v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<AuthSession?> load() async {
    try {
      final raw = await _storage
          .read(key: _sessionKey)
          .timeout(const Duration(milliseconds: 350));
      if ((raw ?? '').trim().isEmpty) return null;
      final decoded = jsonDecode(raw!);
      if (decoded is! Map<String, dynamic>) return null;
      final session = AuthSession.fromJson(decoded);
      if (session.userId.isEmpty || session.email.isEmpty) return null;
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    try {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {}
  }
}
