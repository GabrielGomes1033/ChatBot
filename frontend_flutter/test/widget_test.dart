import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/app.dart';

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
}
