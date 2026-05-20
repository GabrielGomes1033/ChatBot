import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/app.dart';
import 'package:frontend_flutter/models/auth_session.dart';
import 'package:frontend_flutter/screens/auth_gate_screen.dart';
import 'package:frontend_flutter/theme/app_theme.dart';
import 'package:frontend_flutter/widgets/home/chat_shell_widgets.dart'
    show NovaAssistantState, NovaModuleSnapshot;
import 'package:frontend_flutter/widgets/nova_chat_input.dart';
import 'package:frontend_flutter/widgets/nova_message_bubble.dart';
import 'package:frontend_flutter/widgets/nova_modules_panel.dart';
import 'package:frontend_flutter/widgets/nova_sidebar_bio.dart';
import 'package:frontend_flutter/widgets/nova_top_bar.dart';

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

  testWidgets('tela de acesso aguenta paisagem baixa sem quebrar layout',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(() => binding.setSurfaceSize(null));
    await binding.setSurfaceSize(const Size(740, 420));

    await tester.pumpWidget(
      _buildTestHarness(
        const AuthGateScreen(
          onAuthenticated: _noopAuthenticated,
        ),
        textScaler: const TextScaler.linear(1.15),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Entre na sua conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'widgets principais do chat suportam largura android compacta com texto ampliado',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final controller = TextEditingController(
      text: 'Preciso revisar a responsividade do app inteiro no Android.',
    );
    addTearDown(() {
      controller.dispose();
      binding.setSurfaceSize(null);
    });
    await binding.setSurfaceSize(const Size(320, 720));

    await tester.pumpWidget(
      _buildTestHarness(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NovaTopBar(
                  onMenuTap: () {},
                  onUserTap: () {},
                  status: NovaAssistantState.suggesting,
                  contextText:
                      'Contexto ativo: projeto NOVA mobile com documentação, testes, backlog e revisão visual em andamento.',
                  userLabel: 'Gabriel Felipe Gomes de Andrade',
                ),
                const SizedBox(height: 12),
                NovaChatInput(
                  controller: controller,
                  onSend: () {},
                  onMic: () {},
                  onAdd: () {},
                  attachmentName:
                      'documento_de_requisitos_muito_longo_para_validar_overflow_mobile_android.pdf',
                  onRemoveAttachment: () {},
                  compact: true,
                ),
                const SizedBox(height: 12),
                NovaMessageBubble(
                  fromUser: false,
                  text:
                      'Organizei um plano de correção para responsividade, revisei os componentes mais frágeis e deixei o texto contido para não escapar do card em telas pequenas.',
                  timestamp: _fixedTimestamp,
                ),
                const SizedBox(height: 12),
                NovaModulesPanel(
                  compact: true,
                  spotlight: true,
                  onModuleTap: (_) {},
                  modules: const [
                    NovaModuleSnapshot(
                      title: 'Cerebro operacional',
                      description:
                          'Memória, contexto e histórico do projeto sincronizados para retomada rápida.',
                      metric: '12 ctx',
                      icon: Icons.psychology_alt_rounded,
                      active: true,
                    ),
                    NovaModuleSnapshot(
                      title: 'Automacao de entregas',
                      description:
                          'Checklist, prioridades e execução guiada para Android, web e desktop.',
                      metric: 'rodando',
                      icon: Icons.bolt_rounded,
                      active: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const NovaSidebarBio(
                  statusLabel: 'Sugerindo próximos passos',
                  contextText:
                      'Assistente inteligente para organizar ideias, revisar bugs, validar memória e estabilizar a interface sem estourar conteúdo.',
                  compact: true,
                  spotlight: true,
                ),
              ],
            ),
          ),
        ),
        textScaler: const TextScaler.linear(1.30),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Contexto ativo'), findsOneWidget);
    expect(find.textContaining('Organizei um plano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noopAuthenticated(AuthSession _) {}

final DateTime _fixedTimestamp = DateTime(2026, 5, 19, 10, 30);

Widget _buildTestHarness(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: child,
    ),
  );
}
