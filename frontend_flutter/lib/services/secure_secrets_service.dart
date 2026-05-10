import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSecretsService {
  static const _kTelegramToken = 'nova.telegram.token';
  static const _kTelegramChatId = 'nova.telegram.chat_id';
  static const _kApiToken = 'nova.api.token';
  static const _kApiBaseUrl = 'nova.api.base_url';
  static const _kAdminPinHash = 'nova.admin.pin_hash';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _readTimeout = Duration(milliseconds: 350);

  Future<Map<String, String>> readConfigSecrets() async {
    try {
      final token =
          await _storage.read(key: _kTelegramToken).timeout(_readTimeout) ?? '';
      final chatId =
          await _storage.read(key: _kTelegramChatId).timeout(_readTimeout) ??
              '';
      final apiToken =
          await _storage.read(key: _kApiToken).timeout(_readTimeout) ?? '';
      final apiBaseUrl =
          await _storage.read(key: _kApiBaseUrl).timeout(_readTimeout) ?? '';
      return {
        'telegram_token': token,
        'telegram_chat_id': chatId,
        'api_token': apiToken,
        'api_base_url': apiBaseUrl,
      };
    } catch (_) {
      return {
        'telegram_token': '',
        'telegram_chat_id': '',
        'api_token': '',
        'api_base_url': '',
      };
    }
  }

  Future<void> saveConfigSecrets({
    required String telegramToken,
    required String telegramChatId,
    required String apiToken,
    required String apiBaseUrl,
  }) async {
    try {
      await _storage.write(key: _kTelegramToken, value: telegramToken.trim());
      await _storage.write(
        key: _kTelegramChatId,
        value: telegramChatId.trim(),
      );
      await _storage.write(key: _kApiToken, value: apiToken.trim());
      await _storage.write(key: _kApiBaseUrl, value: apiBaseUrl.trim());
    } catch (_) {}
  }

  Future<void> saveApiConnectionConfig({
    required String apiBaseUrl,
    required String apiToken,
  }) async {
    try {
      await _storage.write(key: _kApiBaseUrl, value: apiBaseUrl.trim());
      await _storage.write(key: _kApiToken, value: apiToken.trim());
    } catch (_) {}
  }

  Future<bool> hasAdminPin() async {
    final h = await _storage.read(key: _kAdminPinHash);
    return (h ?? '').isNotEmpty;
  }

  Future<void> setAdminPin(String pin) async {
    final hash = _pinHash(pin);
    await _storage.write(key: _kAdminPinHash, value: hash);
  }

  Future<bool> validateAdminPin(String pin) async {
    final saved = await _storage.read(key: _kAdminPinHash) ?? '';
    if (saved.isEmpty) return false;
    return saved == _pinHash(pin);
  }

  Future<void> clearAdminPin() async {
    await _storage.delete(key: _kAdminPinHash);
  }

  String _pinHash(String pin) {
    final normalized = pin.trim();
    final bytes = utf8.encode('nova::$normalized::v1');
    return sha256.convert(bytes).toString();
  }
}
