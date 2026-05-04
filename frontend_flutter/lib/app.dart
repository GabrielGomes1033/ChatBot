import 'package:flutter/material.dart';

import 'screens/nova_chat_screen.dart';
import 'theme/app_theme.dart';

// Widget raiz do aplicativo.
// Ele configura tema, título e rota inicial.
class NovaFrontendApp extends StatelessWidget {
  const NovaFrontendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOVA',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const NovaChatScreen(),
    );
  }
}
