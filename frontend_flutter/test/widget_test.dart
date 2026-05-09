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
}
