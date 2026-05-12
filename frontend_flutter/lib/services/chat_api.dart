import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'api_endpoint_config.dart';

typedef ApiHttpExecutor = Future<http.Response> Function(
  String method,
  Uri uri, {
  required Map<String, String> headers,
  String? encodedBody,
});

class ApiHttpException implements Exception {
  ApiHttpException({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.url,
    required this.message,
    this.responseBody = '',
  });

  final String method;
  final String path;
  final int statusCode;
  final String url;
  final String message;
  final String responseBody;

  @override
  String toString() {
    return 'API $method $path falhou (HTTP $statusCode). $message';
  }
}

class ChatApiService {
  static const String _definedApiToken = String.fromEnvironment(
    'NOVA_API_TOKEN',
    defaultValue: '',
  );

  ChatApiService({
    String? baseUrl,
    String? apiToken,
    ApiHttpExecutor? httpExecutor,
  })  : _endpoint = ApiEndpointConfig.resolve(explicitBaseUrl: baseUrl),
        _apiToken = _normalizeApiToken(
          apiToken,
          fallback: _definedApiToken,
        ),
        _hasExplicitBaseUrl = (baseUrl?.trim().isNotEmpty == true),
        _httpExecutor = httpExecutor {
    if (_hasExplicitBaseUrl) {
      _hasDiscoveredBackend = true;
    }
  }

  static const Duration _requestTimeout = Duration(seconds: 18);

  ApiEndpointConfig _endpoint;
  String _apiToken;
  bool _hasExplicitBaseUrl;
  bool _hasDiscoveredBackend = false;
  final ApiHttpExecutor? _httpExecutor;

  String get baseUrl => _endpoint.baseUrl;
  String get baseUrlSource => _endpoint.source;
  String get apiToken => _apiToken;

  void updateBaseUrl(String? baseUrl) {
    _endpoint = ApiEndpointConfig.resolve(explicitBaseUrl: baseUrl);
    _hasExplicitBaseUrl = (baseUrl?.trim().isNotEmpty == true);
    _hasDiscoveredBackend = _hasExplicitBaseUrl;
  }

  void updateApiToken(String? apiToken) {
    _apiToken = _normalizeApiToken(
      apiToken,
      fallback: _definedApiToken,
    );
  }

  void updateConnection({
    String? baseUrl,
    String? apiToken,
  }) {
    updateBaseUrl(baseUrl);
    updateApiToken(apiToken);
  }

  Uri _uriForBase(String baseUrl, String path) => Uri.parse('$baseUrl$path');

  static String _normalizeApiToken(
    String? raw, {
    String fallback = '',
  }) {
    final normalized = (raw ?? '').trim();
    if (normalized.isNotEmpty) return normalized;
    return fallback.trim();
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_apiToken.isNotEmpty) {
      headers['X-API-Key'] = _apiToken;
      headers['Authorization'] = 'Bearer $_apiToken';
    }
    return headers;
  }

  Future<http.Response> _performHttp(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? encodedBody,
  }) {
    if (_httpExecutor != null) {
      return _httpExecutor!(
        method,
        uri,
        headers: headers,
        encodedBody: encodedBody,
      );
    }
    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers).timeout(_requestTimeout);
      case 'POST':
        return http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout);
      case 'PUT':
        return http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout);
      case 'DELETE':
        return http.delete(uri, headers: headers).timeout(_requestTimeout);
      default:
        throw Exception('Metodo HTTP nao suportado: $method');
    }
  }

  List<String> _fallbackPaths(String path) {
    final out = <String>[];

    if (!path.startsWith('/api/')) {
      out.add('/api$path');
    }
    if (path.startsWith('/api/')) {
      out.add(path.replaceFirst('/api', ''));
    }

    if (path == '/autonomy/status') {
      out.add('/autonomia/status');
    } else if (path == '/autonomy/config') {
      out.add('/autonomia/config');
    } else if (path == '/autonomy/task') {
      out.add('/autonomia/tarefa');
      out.add('/autonomia/task');
    } else if (path == '/documents/analyze') {
      out.add('/documentos/analisar');
      out.add('/document/analyze');
      out.add('/docs/analyze');
    } else if (path == '/images/inspect') {
      out.add('/image/inspect');
    } else if (path == '/jarvis/status') {
      out.add('/assistant/status');
    }

    final seen = <String>{path};
    final deduped = <String>[];
    for (final item in out) {
      if (item.trim().isEmpty) continue;
      if (seen.add(item)) deduped.add(item);
    }
    return deduped;
  }

  String _endpointHint({
    required String path,
    required int statusCode,
    required String body,
  }) {
    if (path.startsWith('/auth/') && statusCode == 401) {
      return 'Email ou senha inválidos.';
    }
    if (path.startsWith('/auth/') && statusCode == 404) {
      return 'Endpoint de autenticação não encontrado nesse backend. '
          'Atualize o deploy para expor /auth/* e /api/auth/*.';
    }
    if (statusCode == 404 &&
        (path.startsWith('/autonomy') ||
            path.startsWith('/jarvis') ||
            path.startsWith('/actions') ||
            path.startsWith('/dev') ||
            path.startsWith('/documents') ||
            path.startsWith('/images') ||
            path.startsWith('/agent') ||
            path.startsWith('/ops') ||
            path.startsWith('/help') ||
            path.startsWith('/memory/subjects') ||
            path.startsWith('/memory/recent') ||
            path.startsWith('/brain') ||
            path.startsWith('/voice/status'))) {
      return 'Endpoint não encontrado nesse backend. '
          'A API está desatualizada para este recurso. '
          'Atualize/deploy o `backend_python/api_server.py` mais recente.';
    }
    if (statusCode == 401) {
      return 'Não autorizado. Verifique token/credenciais da API.';
    }
    if (statusCode == 403) {
      return 'Acesso negado (RBAC/permissão).';
    }
    if (body.trim().isNotEmpty) {
      return body.trim();
    }
    return 'Falha HTTP $statusCode';
  }

  Map<String, dynamic> _decodePayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Resposta invalida do servidor.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!_hasExplicitBaseUrl && !_hasDiscoveredBackend) {
      final health = await discoverBackend(explicitBaseUrl: null);
      final reachable = health['reachable'] == true || health['ok'] == true;
      if (!reachable) {
        final message = health['message']?.toString().trim() ??
            'Nenhum backend ativo encontrado para conectar.';
        throw Exception(
          'Falha de conexão com a API em ${_endpoint.baseUrl}$path. $message',
        );
      }
    }
    return _requestJsonAtBase(
      _endpoint.baseUrl,
      method,
      path,
      body: body,
    );
  }

  Future<Map<String, dynamic>> _requestJsonAtBase(
    String baseUrl,
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool allowPathFallback = true,
  }) async {
    final normalizedBaseUrl = ApiEndpointConfig.normalizeBaseUrl(baseUrl);
    final encoded = body == null ? null : jsonEncode(body);
    final headers = _buildHeaders();
    final attempts = <String>[
      path,
      if (allowPathFallback) ..._fallbackPaths(path),
    ];
    ApiHttpException? lastError;

    for (var i = 0; i < attempts.length; i++) {
      final currentPath = attempts[i];
      final uri = _uriForBase(normalizedBaseUrl, currentPath);

      late http.Response response;
      try {
        response = await _performHttp(
          method,
          uri,
          headers: headers,
          encodedBody: encoded,
        );
      } on TimeoutException {
        throw Exception(
          'Tempo esgotado ao conectar com a API em ${uri.toString()}.',
        );
      } catch (e) {
        throw Exception(
          'Falha de conexão com a API em ${uri.toString()}: ${e.toString()}',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = _decodePayload(response.body);
        if (payload['ok'] != true) {
          throw Exception(payload['error']?.toString() ?? 'erro_desconhecido');
        }
        return payload;
      }

      final bodyPreview = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
      final hint = _endpointHint(
        path: currentPath,
        statusCode: response.statusCode,
        body: bodyPreview,
      );
      lastError = ApiHttpException(
        method: method,
        path: currentPath,
        statusCode: response.statusCode,
        url: uri.toString(),
        message: hint,
        responseBody: bodyPreview,
      );

      final isLast = i == attempts.length - 1;
      if (response.statusCode != 404 || isLast) {
        break;
      }
    }

    throw lastError ??
        ApiHttpException(
          method: method,
          path: path,
          statusCode: 0,
          url: _uriForBase(normalizedBaseUrl, path).toString(),
          message: 'Falha desconhecida ao chamar API.',
        );
  }

  List<String> _healthProbePaths() {
    return const [
      '/health',
      '/api/health',
      '/healthz',
      '/api/healthz',
      '/status',
      '/api/status',
      '/system/status',
      '/api/system/status',
    ];
  }

  bool _looksHealthyPayload(Map<String, dynamic> payload) {
    final ok = payload['ok'];
    if (ok == true) return true;

    final healthy = payload['healthy'];
    if (healthy == true) return true;

    final status = (payload['status'] ?? payload['state'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'ok' ||
        status == 'healthy' ||
        status == 'up' ||
        status == 'running') {
      return true;
    }

    if (payload.containsKey('version') ||
        payload.containsKey('service') ||
        payload.containsKey('uptime')) {
      return true;
    }

    return false;
  }

  Future<Map<String, dynamic>> _probeHealthAtBase(
    ApiEndpointConfig candidate,
  ) async {
    dynamic lastError;

    for (final path in _healthProbePaths()) {
      try {
        final payload = await _requestJsonAtBase(
          candidate.baseUrl,
          'GET',
          path,
          allowPathFallback: false,
        );

        if (_looksHealthyPayload(payload)) {
          return {
            ...payload,
            'ok': true,
            'reachable': true,
            'health_path': path,
          };
        }

        return {
          ...payload,
          'ok': payload['ok'] == true,
          'reachable': true,
          'health_path': path,
        };
      } on ApiHttpException catch (e) {
        lastError = e;
        if (e.statusCode == 404) {
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    throw Exception(
        'Nenhuma rota de saúde respondeu para ${candidate.baseUrl}.');
  }

  Future<Map<String, dynamic>> discoverBackend({
    String? explicitBaseUrl,
  }) async {
    final candidates = ApiEndpointConfig.candidates(
      explicitBaseUrl: explicitBaseUrl,
    );
    final attempts = <Map<String, dynamic>>[];

    for (final candidate in candidates) {
      try {
        final payload = await _probeHealthAtBase(candidate);
        _endpoint = candidate;
        _hasDiscoveredBackend = true;
        return {
          ...payload,
          'reachable': true,
          'base_url': candidate.baseUrl,
          'source': candidate.source,
          'attempts': attempts,
        };
      } catch (e) {
        attempts.add({
          'base_url': candidate.baseUrl,
          'source': candidate.source,
          'error': e.toString().replaceFirst('Exception: ', ''),
        });
      }
    }

    return {
      'ok': false,
      'reachable': false,
      'base_url': _endpoint.baseUrl,
      'source': _endpoint.source,
      'attempts': attempts,
      'message': attempts.isEmpty
          ? 'Nenhum endpoint candidato disponivel.'
          : attempts.first['error'],
    };
  }

  Future<Map<String, dynamic>> getHealthProfile() {
    return _requestJson('GET', '/health');
  }

  Future<AuthSession> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final payload = await _requestAuthJson(
      method: 'POST',
      path: '/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    final session = payload['session'];
    if (session is! Map) {
      throw Exception('Sessão inválida recebida no cadastro.');
    }
    return AuthSession.fromJson(Map<String, dynamic>.from(session));
  }

  Future<AuthSession> loginUser({
    required String email,
    required String password,
  }) async {
    final payload = await _requestAuthJson(
      method: 'POST',
      path: '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );
    final session = payload['session'];
    if (session is! Map) {
      throw Exception('Sessão inválida recebida no login.');
    }
    return AuthSession.fromJson(Map<String, dynamic>.from(session));
  }

  Future<AuthSession> fetchUserProfile(String userId) async {
    final payload = await _requestAuthJson(
      method: 'GET',
      path: '/auth/profile?user_id=${Uri.encodeComponent(userId.trim())}',
    );
    final session = payload['session'];
    if (session is! Map) {
      throw Exception('Sessão inválida recebida no perfil.');
    }
    return AuthSession.fromJson(Map<String, dynamic>.from(session));
  }

  Future<Map<String, dynamic>> _requestAuthJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      return await _requestJsonAtBase(
        _endpoint.baseUrl,
        method,
        path,
        body: body,
        allowPathFallback: false,
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode != 404) rethrow;
      final fallbackPath = path.startsWith('/auth/')
          ? '/api$path'
          : path.replaceFirst('/api/auth/', '/auth/');
      return _requestJsonAtBase(
        _endpoint.baseUrl,
        method,
        fallbackPath,
        body: body,
        allowPathFallback: false,
      );
    }
  }

  Future<Map<String, dynamic>> sendJarvisMessage(
    String message, {
    String userId = 'frontend',
    String mode = 'normal',
    bool autoApprove = false,
    String? fileId,
    String? context,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'text': message,
      'mode': mode,
      'auto_approve': autoApprove,
    };
    if ((fileId ?? '').trim().isNotEmpty) {
      body['file_id'] = fileId!.trim();
    }
    if ((context ?? '').trim().isNotEmpty) {
      body['context'] = context!.trim();
    }
    try {
      final payload = await _requestJson(
        'POST',
        '/chat',
        body: body,
      );
      final reply = payload['reply']?.toString().trim() ?? '';
      if (reply.isNotEmpty &&
          reply.toLowerCase() != 'mensagem vazia.' &&
          reply.toLowerCase() != 'mensagem vazia') {
        return payload;
      }
      return _requestJson(
        'POST',
        '/chat',
        body: {
          'message': message,
          if ((fileId ?? '').trim().isNotEmpty) 'file_id': fileId!.trim(),
          if ((context ?? '').trim().isNotEmpty) 'context': context!.trim(),
        },
      );
    } on ApiHttpException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 400) rethrow;
      return _requestJson(
        'POST',
        '/chat',
        body: {
          'message': message,
          if ((fileId ?? '').trim().isNotEmpty) 'file_id': fileId!.trim(),
          if ((context ?? '').trim().isNotEmpty) 'context': context!.trim(),
        },
      );
    }
  }

  Future<String> sendMessage(String message) async {
    final payload = await sendJarvisMessage(message);
    return payload['reply']?.toString() ?? 'Sem resposta.';
  }

  Future<bool> healthCheck() async {
    final payload = await getHealthProfile();
    return payload['ok'] == true;
  }

  Future<Map<String, dynamic>> getSecurityAudit() async {
    final payload = await _requestJson('GET', '/security/audit');
    final audit = payload['audit'];
    if (audit is Map<String, dynamic>) return audit;
    if (audit is Map) return Map<String, dynamic>.from(audit);
    return {};
  }

  Future<List<Map<String, dynamic>>> getSecurityAuditHistory({
    int limit = 30,
  }) async {
    final lim = limit.clamp(1, 200);
    final payload =
        await _requestJson('GET', '/security/audit/history?limit=$lim');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSessionAudit({
    int limit = 120,
  }) async {
    final lim = limit.clamp(1, 1000);
    final payload =
        await _requestJson('GET', '/security/session-audit?limit=$lim');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> verifySessionAuditChain() {
    return _requestJson('GET', '/security/session-audit/verify');
  }

  Future<Map<String, dynamic>> getAdminState() {
    return _requestJson('GET', '/admin/state');
  }

  Future<List<Map<String, dynamic>>> getKnowledge() async {
    final payload = await _requestJson('GET', '/knowledge');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> createKnowledge({
    required String gatilho,
    required String resposta,
    required String categoria,
  }) async {
    final payload = await _requestJson(
      'POST',
      '/knowledge',
      body: {
        'gatilho': gatilho,
        'resposta': resposta,
        'categoria': categoria,
      },
    );
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> updateKnowledge(
    String id, {
    String? gatilho,
    String? resposta,
    String? categoria,
    bool? ativo,
  }) async {
    final body = <String, dynamic>{};
    if (gatilho != null) body['gatilho'] = gatilho;
    if (resposta != null) body['resposta'] = resposta;
    if (categoria != null) body['categoria'] = categoria;
    if (ativo != null) body['ativo'] = ativo;
    final payload = await _requestJson('PUT', '/knowledge/$id', body: body);
    final item = payload['item'];
    if (item is! Map) return {};
    return Map<String, dynamic>.from(item);
  }

  Future<List<Map<String, dynamic>>> deleteKnowledge(String id) async {
    final payload = await _requestJson('DELETE', '/knowledge/$id');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final payload = await _requestJson('GET', '/admin/users');
    final users = payload['users'];
    if (users is! List) return [];
    return users
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> addUser(
    String name, {
    String email = '',
    String password = '',
  }) async {
    final payload = await _requestJson(
      'POST',
      '/admin/users',
      body: {
        'nome': name,
        'papel': 'usuario',
        if (email.trim().isNotEmpty) 'email': email.trim(),
        if (password.trim().isNotEmpty) 'senha': password.trim(),
      },
    );
    final users = payload['users'];
    if (users is! List) return [];
    return users
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> updateUser(
    String id, {
    String? name,
    bool? active,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['nome'] = name;
    if (active != null) body['ativo'] = active;
    final payload = await _requestJson('PUT', '/admin/users/$id', body: body);
    final users = payload['users'];
    if (users is! List) return [];
    return users
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> deleteUser(String id) async {
    final payload = await _requestJson('DELETE', '/admin/users/$id');
    final users = payload['users'];
    if (users is! List) return [];
    return users
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getConfig() async {
    final payload = await _requestJson('GET', '/admin/config');
    final config = payload['config'];
    if (config is! Map) return {};
    return Map<String, dynamic>.from(config);
  }

  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> config) async {
    final payload = await _requestJson('POST', '/admin/config', body: config);
    final cfg = payload['config'];
    if (cfg is! Map) return {};
    return Map<String, dynamic>.from(cfg);
  }

  Future<String> sendTelegram(String message) async {
    final payload = await _requestJson('POST', '/telegram/send',
        body: {'message': message});
    return payload['message']?.toString() ?? 'Mensagem enviada.';
  }

  Future<Map<String, dynamic>> getMarketQuotes() async {
    final payload = await _requestJson('GET', '/market/quotes');
    final quotes = payload['quotes'];
    if (quotes is! Map) return {};
    return Map<String, dynamic>.from(quotes);
  }

  Future<String> getWeatherNow({String city = ''}) async {
    final suffix = city.trim().isEmpty
        ? '/weather/now'
        : '/weather/now?city=${Uri.encodeComponent(city.trim())}';
    final payload = await _requestJson('GET', suffix);
    return payload['summary']?.toString() ?? 'Sem clima no momento.';
  }

  Future<String> getWeatherByCoords({
    required double latitude,
    required double longitude,
  }) async {
    final suffix =
        '/weather/by-coords?lat=${Uri.encodeComponent(latitude.toString())}&lon=${Uri.encodeComponent(longitude.toString())}';
    final payload = await _requestJson('GET', suffix);
    return payload['summary']?.toString() ?? 'Sem clima por coordenadas.';
  }

  Future<Map<String, dynamic>> getCurrentLocation() async {
    final payload = await _requestJson('GET', '/location/current');
    final loc = payload['location'];
    if (loc is Map<String, dynamic>) return loc;
    if (loc is Map) return Map<String, dynamic>.from(loc);
    return {};
  }

  Future<Map<String, dynamic>> reverseLocation({
    required double latitude,
    required double longitude,
  }) async {
    final suffix =
        '/location/reverse?lat=${Uri.encodeComponent(latitude.toString())}&lon=${Uri.encodeComponent(longitude.toString())}';
    final payload = await _requestJson('GET', suffix);
    return payload;
  }

  Future<Map<String, dynamic>> searchMapPlaces(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final buffer =
        StringBuffer('/maps/search?q=${Uri.encodeComponent(query.trim())}');
    if (latitude != null) {
      buffer.write('&lat=${Uri.encodeComponent(latitude.toString())}');
    }
    if (longitude != null) {
      buffer.write('&lon=${Uri.encodeComponent(longitude.toString())}');
    }
    final payload = await _requestJson('GET', buffer.toString());
    return payload;
  }

  Future<Map<String, dynamic>> updateLocation({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    final payload = await _requestJson(
      'POST',
      '/location/update',
      body: {
        'label': label,
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
      },
    );
    final loc = payload['location'];
    if (loc is Map<String, dynamic>) return loc;
    if (loc is Map) return Map<String, dynamic>.from(loc);
    return {};
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final payload = await _requestJson('GET', '/reminders');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> addReminder({
    required String text,
    String when = '',
  }) async {
    return _requestJson(
      'POST',
      '/reminders',
      body: {'text': text, 'when': when},
    );
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final payload = await _requestJson('GET', '/backup/export');
    final backup = payload['backup'];
    if (backup is Map<String, dynamic>) return backup;
    if (backup is Map) return Map<String, dynamic>.from(backup);
    return {};
  }

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    await _requestJson('POST', '/backup/restore', body: {'backup': backup});
  }

  Future<Map<String, dynamic>> synthesizeNeuralVoice(
    String text, {
    String voiceProfile = 'feminina',
  }) {
    return _requestJson(
      'POST',
      '/voice/neural',
      body: {
        'text': text,
        'voice_profile': voiceProfile,
      },
    );
  }

  Future<Map<String, dynamic>> getObservabilitySummary({
    int window = 200,
  }) async {
    final win = window.clamp(1, 500);
    final payload =
        await _requestJson('GET', '/observability/summary?window=$win');
    final summary = payload['summary'];
    if (summary is Map<String, dynamic>) return summary;
    if (summary is Map) return Map<String, dynamic>.from(summary);
    return {};
  }

  Future<List<Map<String, dynamic>>> getObservabilityTraces({
    int limit = 120,
  }) async {
    final lim = limit.clamp(1, 500);
    final payload =
        await _requestJson('GET', '/observability/traces?limit=$lim');
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> agentPlan(String objective) {
    return _requestJson(
      'POST',
      '/agent/plan',
      body: {'objective': objective},
    );
  }

  Future<Map<String, dynamic>> agentExecute(String objective) {
    return _requestJson(
      'POST',
      '/agent/execute',
      body: {'objective': objective},
    );
  }

  Future<Map<String, dynamic>> ragQuery(String query) {
    return _requestJson(
      'POST',
      '/rag/query',
      body: {'query': query},
    );
  }

  Future<Map<String, dynamic>> ragFeedback({
    required String query,
    required String chunkId,
    required int score,
  }) {
    return _requestJson(
      'POST',
      '/rag/feedback',
      body: {
        'query': query,
        'chunk_id': chunkId,
        'score': score,
      },
    );
  }

  Future<Map<String, dynamic>> ragFeedbackStats() {
    return _requestJson('GET', '/rag/feedback/stats');
  }

  Future<Map<String, dynamic>> getSystemStatus() {
    return _requestJson('GET', '/system/status');
  }

  Future<Map<String, dynamic>> getOpsStatus() {
    return _requestJson('GET', '/ops/status');
  }

  Future<Map<String, dynamic>> getSubjectMemory({
    int limit = 8,
  }) {
    final lim = limit.clamp(1, 50);
    return _requestJson('GET', '/memory/subjects?limit=$lim');
  }

  Future<Map<String, dynamic>> getJarvisStatus() {
    return _requestJson('GET', '/jarvis/status');
  }

  Future<List<Map<String, dynamic>>> getRecentMemory({
    String userId = 'frontend',
    int limit = 8,
  }) async {
    final lim = limit.clamp(1, 50);
    final payload = await _requestJson(
      'GET',
      '/memory/recent?user_id=${Uri.encodeComponent(userId)}&limit=$lim',
    );
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchRecentMemory({
    required String query,
    String userId = 'frontend',
    int limit = 8,
  }) async {
    final lim = limit.clamp(1, 50);
    final payload = await _requestJson(
      'GET',
      '/memory/search?user_id=${Uri.encodeComponent(userId)}&query=${Uri.encodeComponent(query)}&limit=$lim',
    );
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getBrainNotes({
    String query = '',
    int limit = 12,
  }) async {
    final lim = limit.clamp(1, 200);
    final payload = await _requestJson(
      'GET',
      '/brain/notes?query=${Uri.encodeComponent(query)}&limit=$lim',
    );
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getBrainNote(String noteRef) async {
    final payload = await _requestJson(
        'GET', '/brain/notes/${Uri.encodeComponent(noteRef)}');
    final note = payload['note'];
    if (note is Map<String, dynamic>) return note;
    if (note is Map) return Map<String, dynamic>.from(note);
    return {};
  }

  Future<Map<String, dynamic>> saveBrainNote({
    required String title,
    required String content,
    String folder = '',
  }) async {
    final payload = await _requestJson(
      'POST',
      '/brain/notes',
      body: {
        'title': title,
        'content': content,
        'folder': folder,
      },
    );
    final note = payload['note'];
    if (note is Map<String, dynamic>) return note;
    if (note is Map) return Map<String, dynamic>.from(note);
    return {};
  }

  Future<Map<String, dynamic>> getBrainBacklinks(String noteRef) {
    return _requestJson(
      'GET',
      '/brain/backlinks/${Uri.encodeComponent(noteRef)}',
    );
  }

  Future<Map<String, dynamic>> getBrainGraph() {
    return _requestJson('GET', '/brain/graph');
  }

  Future<List<Map<String, dynamic>>> getBrainSuggestions({
    String noteRef = '',
    int limit = 12,
  }) async {
    final lim = limit.clamp(1, 200);
    final payload = await _requestJson(
      'GET',
      '/brain/suggestions?note_ref=${Uri.encodeComponent(noteRef)}&limit=$lim',
    );
    final items = payload['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getJarvisTools() async {
    final payload = await _requestJson('GET', '/actions/tools');
    final tools = payload['tools'];
    if (tools is! List) return [];
    return tools
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> approveJarvisAction({
    required String toolName,
    required Map<String, dynamic> params,
    String userId = 'frontend',
    String promptText = '',
  }) {
    return _requestJson(
      'POST',
      '/actions/approve',
      body: {
        'user_id': userId,
        'tool_name': toolName,
        'params': params,
        'prompt_text': promptText,
      },
    );
  }

  Future<Map<String, dynamic>> getVoiceStatus() {
    return _requestJson('GET', '/voice/status');
  }

  Future<Map<String, dynamic>> getHelpTopics() {
    return _requestJson('GET', '/help/topics');
  }

  Future<Map<String, dynamic>> getAutonomyStatus() {
    return _requestJson('GET', '/autonomy/status');
  }

  Future<Map<String, dynamic>> getAutonomyConfig() async {
    final payload = await _requestJson('GET', '/autonomy/config');
    final cfg = payload['config'];
    if (cfg is Map<String, dynamic>) return cfg;
    if (cfg is Map) return Map<String, dynamic>.from(cfg);
    return {};
  }

  Future<Map<String, dynamic>> updateAutonomyConfig({
    bool? active,
    String? riskLevel,
    String? freedomLevel,
    bool? confirmSensitive,
  }) async {
    final body = <String, dynamic>{};
    if (active != null) body['active'] = active;
    if (riskLevel != null && riskLevel.trim().isNotEmpty) {
      body['risk_level'] = riskLevel.trim().toLowerCase();
    }
    if (freedomLevel != null && freedomLevel.trim().isNotEmpty) {
      body['freedom_level'] = freedomLevel.trim().toLowerCase();
    }
    if (confirmSensitive != null) {
      body['confirm_sensitive'] = confirmSensitive;
    }
    final payload = await _requestJson('POST', '/autonomy/config', body: body);
    final cfg = payload['config'];
    if (cfg is Map<String, dynamic>) return cfg;
    if (cfg is Map) return Map<String, dynamic>.from(cfg);
    return {};
  }

  Future<Map<String, dynamic>> enqueueAutonomyTask({
    required String objective,
    String source = 'frontend',
  }) async {
    try {
      return await _requestJson(
        'POST',
        '/autonomy/task',
        body: {'objective': objective, 'source': source},
      );
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404) {
        throw Exception(
          'Seu backend atual não possui a rota de autonomia. '
          'Atualize o deploy da API para habilitar o enfileiramento de tarefas.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeDocument({
    required String fileName,
    required Uint8List bytes,
    bool? autoLearn,
  }) async {
    final body = <String, dynamic>{
      'filename': fileName,
      'content_base64': base64Encode(bytes),
    };
    if (autoLearn != null) {
      body['auto_learn'] = autoLearn;
    }
    try {
      return await _requestJson(
        'POST',
        '/documents/analyze',
        body: body,
      );
    } on ApiHttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        try {
          return await _requestJson(
            'POST',
            '/documents/inspect',
            body: {
              'filename': fileName,
              'content_base64': base64Encode(bytes),
              'auto_learn': false,
            },
          );
        } on ApiHttpException catch (inspectError) {
          if (inspectError.statusCode != 404) {
            return _buildLocalDocumentFallback(
              fileName: fileName,
              bytes: bytes,
              reason: inspectError.message,
            );
          }
        }
      }
      if (e.statusCode == 404) {
        return _buildLocalDocumentFallback(
          fileName: fileName,
          bytes: bytes,
          reason: e.message,
        );
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        return _buildLocalDocumentFallback(
          fileName: fileName,
          bytes: bytes,
          reason: e.message,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeImageInsights({
    required String fileName,
    required String recognizedText,
    required List<Map<String, dynamic>> labels,
    required Map<String, dynamic> metadata,
    required bool fromCamera,
    required int byteSize,
  }) {
    return _requestJson(
      'POST',
      '/images/inspect',
      body: {
        'filename': fileName,
        'recognized_text': recognizedText,
        'labels': labels,
        'metadata': metadata,
        'from_camera': fromCamera,
        'byte_size': byteSize,
      },
    );
  }

  Future<Map<String, dynamic>> uploadFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = '',
    String source = 'upload',
  }) {
    return _requestJson(
      'POST',
      '/files/upload',
      body: {
        'filename': fileName,
        'content_base64': base64Encode(bytes),
        'mime_type': mimeType,
        'source': source,
      },
    );
  }

  Future<Map<String, dynamic>> analyzeUploadedFile({
    required String fileId,
    String question = '',
    String context = '',
    String recognizedText = '',
    List<Map<String, dynamic>> labels = const [],
    Map<String, dynamic> metadata = const {},
    bool fromCamera = false,
  }) {
    return _requestJson(
      'POST',
      '/files/analyze',
      body: {
        'file_id': fileId,
        'question': question,
        'context': context,
        'recognized_text': recognizedText,
        'labels': labels,
        'metadata': metadata,
        'from_camera': fromCamera,
      },
    );
  }

  Future<Map<String, dynamic>> _postAction(
    String path, {
    String userId = 'frontend',
    Map<String, dynamic> extra = const {},
  }) {
    return _requestJson(
      'POST',
      path,
      body: {
        'user_id': userId,
        ...extra,
      },
    );
  }

  Future<Map<String, dynamic>> continueProjectAction({
    String userId = 'frontend',
    String context = '',
  }) {
    return _postAction(
      '/actions/continue-project',
      userId: userId,
      extra: {
        if (context.trim().isNotEmpty) 'context': context.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> generateCodeAction({
    String userId = 'frontend',
    String context = '',
    String language = '',
  }) {
    return _postAction(
      '/actions/generate-code',
      userId: userId,
      extra: {
        if (context.trim().isNotEmpty) 'context': context.trim(),
        if (language.trim().isNotEmpty) 'language': language.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> improveInterfaceAction({
    String userId = 'frontend',
    String context = '',
  }) {
    return _postAction(
      '/actions/improve-interface',
      userId: userId,
      extra: {
        if (context.trim().isNotEmpty) 'context': context.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> continueFromHereAction({
    String userId = 'frontend',
    String lastAnswer = '',
    String context = '',
  }) {
    return _postAction(
      '/actions/continue-from-here',
      userId: userId,
      extra: {
        if (lastAnswer.trim().isNotEmpty) 'last_answer': lastAnswer.trim(),
        if (context.trim().isNotEmpty) 'context': context.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> openMemoryPanel({
    String userId = 'frontend',
    int limit = 8,
  }) {
    return _postAction(
      '/memory/open',
      userId: userId,
      extra: {'limit': limit},
    );
  }

  Future<Map<String, dynamic>> openMemoryAction({
    String userId = 'frontend',
  }) {
    return _postAction(
      '/actions/open-memory',
      userId: userId,
    );
  }

  String _buildDevFallbackPrompt({
    required String prompt,
    String language = '',
    String projectName = '',
  }) {
    final trimmedPrompt = prompt.trim();
    final trimmedLanguage = language.trim();
    final trimmedProjectName = projectName.trim();
    final buffer = StringBuffer('Gerar codigo: $trimmedPrompt');
    if (trimmedLanguage.isNotEmpty) {
      buffer.write('\nLinguagem: $trimmedLanguage');
    }
    if (trimmedProjectName.isNotEmpty) {
      buffer.write('\nProjeto: $trimmedProjectName');
    }
    return buffer.toString();
  }

  String _buildDevFallbackContext({
    String language = '',
    String projectName = '',
  }) {
    final parts = <String>[];
    final trimmedLanguage = language.trim();
    final trimmedProjectName = projectName.trim();
    if (trimmedLanguage.isNotEmpty) {
      parts.add('Priorizar geracao em $trimmedLanguage.');
    }
    if (trimmedProjectName.isNotEmpty) {
      parts.add('Usar $trimmedProjectName como nome do projeto.');
    }
    return parts.join(' ');
  }

  Future<Map<String, dynamic>> generateDevCode({
    required String prompt,
    String language = '',
    String projectName = '',
    bool autoConfirm = false,
  }) async {
    final body = {
      'prompt': prompt,
      'language': language,
      'project_name': projectName,
      'auto_confirm': autoConfirm,
    };

    try {
      return await _requestJson(
        'POST',
        '/dev/generate',
        body: body,
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode != 404) rethrow;

      final fallbackPayload = await sendJarvisMessage(
        _buildDevFallbackPrompt(
          prompt: prompt,
          language: language,
          projectName: projectName,
        ),
        mode: 'dev',
        context: _buildDevFallbackContext(
          language: language,
          projectName: projectName,
        ),
      );

      return {
        ...fallbackPayload,
        'ok': true,
        'type': fallbackPayload['type'] ?? 'dev',
        'assistant_state': fallbackPayload['assistant_state'] ?? 'suggesting',
        'project_name': fallbackPayload['project_name'] ?? projectName,
        'language': fallbackPayload['language'] ?? language,
        'language_label': fallbackPayload['language_label'] ?? language,
        'copy_label': fallbackPayload['copy_label'] ?? 'Copiar codigo',
      };
    }
  }

  Map<String, dynamic> _buildLocalDocumentFallback({
    required String fileName,
    required Uint8List bytes,
    required String reason,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = normalized.isEmpty ? 0 : normalized.split(' ').length;
    final tokens = RegExp(r'[a-zA-ZÀ-ÿ0-9_]{4,}')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0) ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    final freq = <String, int>{};
    for (final t in tokens) {
      freq[t] = (freq[t] ?? 0) + 1;
    }
    final keywords = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = keywords.take(12).toList();

    final risks = <String>[];
    final riskTokens = {
      'senha',
      'password',
      'token',
      'cpf',
      'rg',
      'cartao',
      'cartão',
      'pix',
      'sigilo',
      'confidencial',
    };
    for (final token in topKeywords.map((e) => e.key)) {
      if (riskTokens.contains(token)) {
        risks.add('Possível dado sensível detectado: "$token".');
      }
    }

    final summary = normalized.isEmpty
        ? 'Arquivo sem texto legível para resumo.'
        : (normalized.length > 420
            ? '${normalized.substring(0, 420)}...'
            : normalized);

    return {
      'ok': true,
      'report': {
        'file_name': fileName,
        'generated_at': DateTime.now().toIso8601String(),
        'stats': {
          'bytes': bytes.length,
          'chars': text.length,
          'words': words,
          'estimated_pages': (words / 450).ceil().clamp(1, 9999),
        },
        'executive_summary': summary,
        'keywords':
            topKeywords.map((e) => {'token': e.key, 'count': e.value}).toList(),
        'risks': risks,
        'sample_excerpts': summary.isEmpty ? [] : [summary],
        'recommendations': [
          'Backend sem endpoint de análise detectado; relatório gerado localmente.',
          'Para aprendizado automático, atualize/deploy a API mais recente.',
        ],
      },
      'learning': {
        'ok': false,
        'skipped': true,
        'local_fallback': true,
        'message': reason,
        'subject_memory': {'subjects': <String>[]},
      },
    };
  }
}
