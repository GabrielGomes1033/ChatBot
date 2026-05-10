import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/app.dart';
import 'package:frontend_flutter/models/auth_session.dart';
import 'package:frontend_flutter/screens/auth_gate_screen.dart';
import 'package:frontend_flutter/theme/app_theme.dart';

void main() {
  testWidgets('renderiza tela de acesso da NOVA sem sessao ativa',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NovaFrontendApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NOVA'), findsWidgets);
    expect(find.textContaining('Entre na sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('tela de acesso permanece funcional em largura mobile',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(() => binding.setSurfaceSize(null));
    await binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(const NovaFrontendApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NOVA'), findsWidgets);
    expect(
      find.textContaining('sofisticada por design'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tela de acesso permanece funcional em largura tablet',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(() => binding.setSurfaceSize(null));
    await binding.setSurfaceSize(const Size(900, 1100));

    await tester.pumpWidget(const NovaFrontendApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tela de acesso aguenta largura compacta com fonte ampliada',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(() => binding.setSurfaceSize(null));
    await binding.setSurfaceSize(const Size(320, 700));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(1.25),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const AuthGateScreen(
            onAuthenticated: _noopAuthenticated,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Entre na sua conta'), findsOneWidget);
    expect(find.text('Configurar API'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noopAuthenticated(AuthSession _) {}
