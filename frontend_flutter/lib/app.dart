import 'package:flutter/material.dart';

import 'models/auth_session.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/nova_chat_screen.dart';
import 'services/auth_session_service.dart';
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
  AuthSession? _session;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _authSessionService.load();
    if (!mounted) return;
    setState(() {
      _session = session;
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
