import 'package:flutter/foundation.dart';

import 'platform_capabilities.dart';

class ApiEndpointConfig {
  ApiEndpointConfig({
    required this.baseUrl,
    required this.source,
  });

  final String baseUrl;
  final String source;

  static const int apiPort = int.fromEnvironment(
    'NOVA_API_PORT',
    defaultValue: 8000,
  );

  static const String productionBaseUrl = 'https://api.andradeegomes.com';
  static const String fallbackBaseUrl = String.fromEnvironment(
    'NOVA_API_FALLBACK_URL',
    defaultValue: productionBaseUrl,
  );

  static String localBaseUrl(
    String host, {
    String scheme = 'http',
  }) {
    return '$scheme://$host:$apiPort';
  }

  static String exampleManualBaseUrl([String host = '192.168.0.25']) {
    return localBaseUrl(host);
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static bool _isPrivateIpv4Host(String host) {
    final parts = host.trim().split('.');
    if (parts.length != 4) return false;

    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
      octets.add(value);
    }

    if (octets[0] == 10) return true;
    if (octets[0] == 127) return true;
    if (octets[0] == 192 && octets[1] == 168) return true;
    if (octets[0] == 169 && octets[1] == 254) return true;
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
    return false;
  }

  static bool _isLocalHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _isLoopbackHost(normalized) ||
        _isPrivateIpv4Host(normalized) ||
        normalized.endsWith('.local');
  }

  static String _defaultSchemeForHost(String host) {
    return _isLocalHost(host) ? 'http' : 'https';
  }

  static List<ApiEndpointConfig> candidates({String? explicitBaseUrl}) {
    final out = <ApiEndpointConfig>[];

    void push(String raw, String source) {
      final normalized = normalizeBaseUrl(raw);
      if (normalized.isEmpty) return;
      if (out.any((item) => item.baseUrl == normalized)) return;
      out.add(ApiEndpointConfig(baseUrl: normalized, source: source));
    }

    final localOverride = normalizeBaseUrl(explicitBaseUrl ?? '');
    if (localOverride.isNotEmpty) {
      push(localOverride, 'configuracao_local');
      return out;
    }

    const defined = String.fromEnvironment('NOVA_API_URL', defaultValue: '');
    final envUrl = normalizeBaseUrl(defined);
    if (envUrl.isNotEmpty) {
      push(envUrl, 'dart_define');
      return out;
    }

    final normalizedFallbackUrl = normalizeBaseUrl(fallbackBaseUrl);

    if (kIsWeb) {
      final host = Uri.base.host.trim();
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      final isLocal = _isLocalHost(host);

      if (host.isNotEmpty) {
        push(Uri.base.origin, 'web_mesma_origem');
        push('$scheme://$host', 'web_host_atual');
      }

      if (isLocal) {
        push(localBaseUrl(host, scheme: scheme), 'web_mesmo_host_api_porta');
        push(localBaseUrl('127.0.0.1', scheme: scheme),
            'web_loopback_api_porta');
        push(localBaseUrl('localhost', scheme: scheme),
            'web_localhost_api_porta');
        push('$scheme://127.0.0.1', 'web_loopback_sem_porta');
        push('$scheme://localhost', 'web_localhost_sem_porta');
      }

      push(normalizedFallbackUrl, 'online_fallback');
      return out;
    }

    if (kReleaseMode) {
      push(normalizedFallbackUrl, 'online_fallback');
    }

    if (PlatformCapabilities.isAndroid) {
      push(localBaseUrl('10.0.2.2'), 'android_emulador');
      push(localBaseUrl('127.0.0.1'), 'android_loopback');
      push(localBaseUrl('localhost'), 'android_localhost');
    }

    push(
      localBaseUrl('127.0.0.1'),
      PlatformCapabilities.isIOS ? 'ios_simulador_ou_local' : 'localhost',
    );
    push(localBaseUrl('localhost'), 'localhost_alias');
    if (!kReleaseMode) {
      push(normalizedFallbackUrl, 'online_fallback');
    }
    return out;
  }

  static ApiEndpointConfig resolve({String? explicitBaseUrl}) {
    return candidates(explicitBaseUrl: explicitBaseUrl).first;
  }

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    if (!value.contains('://')) {
      final inferredHost = Uri.tryParse('https://$value')?.host.trim() ?? '';
      final scheme =
          inferredHost.isEmpty ? 'https' : _defaultSchemeForHost(inferredHost);
      value = '$scheme://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.trim().isEmpty) return '';

    final normalizedPath = uri.path == '/'
        ? ''
        : (uri.path.endsWith('/') && uri.path.length > 1
            ? uri.path.substring(0, uri.path.length - 1)
            : uri.path);

    final normalized = uri.replace(path: normalizedPath);

    final asText = normalized.toString();
    return asText.endsWith('/')
        ? asText.substring(0, asText.length - 1)
        : asText;
  }
}
