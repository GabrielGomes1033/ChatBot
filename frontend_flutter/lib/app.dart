import 'package:flutter/material.dart';

import 'models/auth_session.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/nova_chat_screen.dart';
import 'services/auth_session_service.dart';
import 'services/secure_secrets_service.dart';
import 'theme/app_theme.dart';

// Widget raiz do aplicativo.
// Ele configura tema, título e rota inicial.
class NovaFrontendApp extends StatefulWidget {
  const NovaFrontendApp({super.key});

  @override
  State<NovaFrontendApp> createState() => _NovaFrontendAppState();
}

class _NovaFrontendAppState extends State<NovaFrontendApp> {
  final AuthSessionService _authSessionService = AuthSessionService();
  final SecureSecretsService _secureSecretsService = SecureSecretsService();
  AuthSession? _session;
  bool _loadingSession = true;
  String _apiBaseUrl = '';
  String _apiToken = '';

  @override
  void initState() {
    super.initState();
    _restoreAppState();
  }

  Future<void> _restoreAppState() async {
    final results = await Future.wait<dynamic>([
      _authSessionService.load(),
      _secureSecretsService.readConfigSecrets(),
    ]);
    final session = results[0] as AuthSession?;
    final secrets = Map<String, String>.from(results[1] as Map);
    if (!mounted) return;
    setState(() {
      _session = session;
      _apiBaseUrl = secrets['api_base_url']?.trim() ?? '';
      _apiToken = secrets['api_token']?.trim() ?? '';
      _loadingSession = false;
    });
  }

  Future<void> _handleAuthenticated(AuthSession session) async {
    await _authSessionService.save(session);
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _handleLogout() async {
    await _authSessionService.clear();
    if (!mounted) return;
    setState(() => _session = null);
  }

  Future<void> _handleConnectionChanged({
    required String apiBaseUrl,
    required String apiToken,
  }) async {
    await _secureSecretsService.saveApiConnectionConfig(
      apiBaseUrl: apiBaseUrl,
      apiToken: apiToken,
    );
    if (!mounted) return;
    setState(() {
      _apiBaseUrl = apiBaseUrl;
      _apiToken = apiToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOVA',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: _loadingSession
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : (_session == null
              ? AuthGateScreen(
                  onAuthenticated: (session) {
                    _handleAuthenticated(session);
                  },
                  initialApiBaseUrl: _apiBaseUrl,
                  initialApiToken: _apiToken,
                  onConnectionChanged: _handleConnectionChanged,
                )
              : NovaChatScreen(
                  session: _session!,
                  onLogout: () {
                    _handleLogout();
                  },
                )),
    );
  }
}
