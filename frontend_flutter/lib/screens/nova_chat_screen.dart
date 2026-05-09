import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import 'home_page.dart';

class NovaChatScreen extends StatelessWidget {
  const NovaChatScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AuthSession session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return HomePage(
      session: session,
      onLogout: onLogout,
    );
  }
}
