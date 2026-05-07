import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_endpoint_config.dart';
import '../services/attachment_analysis_service.dart';
import '../services/background_wake_service.dart';
import '../services/app_security_service.dart';
import '../services/camera_service.dart';
import '../services/chat_api.dart';
import '../services/device_connectivity.dart';
import '../services/device_calendar_service.dart';
import '../services/file_service.dart';
import '../services/local_database.dart';
import '../services/memory_service.dart';
import '../services/platform_capabilities.dart';
import '../services/reminder_notifications.dart';
import '../services/secure_secrets_service.dart';
import '../services/speech_formatter.dart';
import '../services/system_scan_service.dart';
import '../theme/colors.dart';
import '../widgets/glass_container.dart';
import '../widgets/nova_chat_input.dart';
import '../widgets/nova_message_bubble.dart';
import '../widgets/nova_sidebar_bio.dart';
import '../widgets/nova_top_bar.dart';
import '../widgets/nova_modules_panel.dart';
import '../widgets/home/brain_widgets.dart';
import '../widgets/home/chat_shell_widgets.dart' hide NovaTopBar;
import '../widgets/home/dialog_widgets.dart';

class _NovaDevGeneratorRequest {
  const _NovaDevGeneratorRequest({
    required this.prompt,
    required this.language,
    required this.projectName,
  });

  final String prompt;
  final String language;
  final String projectName;
}

class _NovaDevLanguageOption {
  const _NovaDevLanguageOption({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ChatApiService _api = ChatApiService();
  final AttachmentAnalysisService _attachmentAnalysis =
      AttachmentAnalysisService();
  late final FileService _fileService = FileService(
    api: _api,
    attachmentAnalysis: _attachmentAnalysis,
  );
  late final CameraService _cameraService = CameraService();
  late final MemoryService _memoryService = MemoryService(api: _api);
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final DeviceConnectivityService _deviceConnectivity =
      DeviceConnectivityService();
  final DeviceCalendarService _deviceCalendar = DeviceCalendarService();
  final AppSecurityService _appSecurity = AppSecurityService();
  final SecureSecretsService _secureSecrets = SecureSecretsService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  final ReminderNotificationsService _notifications =
      ReminderNotificationsService();
  final SystemScanService _systemScan = SystemScanService();

  final List<NovaChatLine> _chat = [];
  List<Map<String, dynamic>> _knowledge = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _config = {
    'voz_ativa': true,
    'voice_neural_hybrid': true,
    'voice_profile': 'feminina',
    'escuta_ativa': true,
    'wake_word': 'nova',
    'continuous_wake': false,
    'push_to_talk_only': true,
    'telegram_ativo': false,
    'telegram_token': '',
    'telegram_chat_id': '',
    'api_token': '',
    'api_base_url': '',
    'calendar_email': '',
    'autonomia_ativa': true,
    'autonomia_nivel_risco': 'alto',
    'autonomia_liberdade': 'alta',
    'autonomia_requer_confirmacao_sensivel': false,
    'auto_document_learning': true,
    'admin_guard': false,
    'allow_voice_on_lock': true,
    'log_consciencia': <dynamic>[],
  };

  String _systemStatus = 'Conectando...';
  NovaAssistantState _assistantState = NovaAssistantState.suggesting;
  bool _speechReady = false;
  bool _isListening = false;
  bool _executedFromVoice = false;
  bool _sending = false;
  bool _loadingState = false;
  bool _preparingAttachment = false;
  NovaAttachment? _composerAttachment;
  bool _continuousWakeMode = false;
  bool _manualListeningStop = false;
  int _speakRequestId = 0;
  bool _adminUnlocked = false;
  DateTime? _adminUnlockedAt;
  List<Map<String, String>> _musicLibrary = [];
  List<Map<String, dynamic>> _reminders = [];
  Map<String, dynamic> _jarvisStatus = {};
  Map<String, dynamic> _voiceStatus = {};
  List<Map<String, dynamic>> _jarvisTools = [];
  List<Map<String, dynamic>> _recentMemory = [];
  List<Map<String, dynamic>> _brainNotes = [];
  List<Map<String, dynamic>> _brainSuggestions = [];
  Map<String, dynamic> _brainGraph = {};
  Map<String, dynamic>? _pendingLocalCalendarEvent;

  bool get _listenModeEnabled => _config['escuta_ativa'] != false;
  bool get _pushToTalkOnly => _config['push_to_talk_only'] != false;
  bool get _effectiveContinuousWake => !_pushToTalkOnly && _continuousWakeMode;

  void _syncApiConnectionSettingsFromConfig() {
    _api.updateConnection(
      baseUrl: _config['api_base_url']?.toString(),
      apiToken: _config['api_token']?.toString(),
    );
  }

  String _buildBackendStatusLine(Map<String, dynamic> health) {
    final reachable = health['reachable'] == true || health['ok'] == true;
    final baseUrl = health['base_url']?.toString().trim().isNotEmpty == true
        ? health['base_url'].toString().trim()
        : _api.baseUrl;
    if (!reachable) {
      return 'Sem conexão com backend em $baseUrl.';
    }

    final assistant = health['assistant']?.toString().trim().isNotEmpty == true
        ? health['assistant'].toString().trim()
        : 'NOVA';
    final apiVersion = health['api_version']?.toString().trim() ?? '';
    final versionSuffix = apiVersion.isEmpty ? '' : ' · API v$apiVersion';
    return '$assistant conectada em $baseUrl$versionSuffix.';
  }

  Future<void> _refreshBackendConnection() async {
    final health = await _api.discoverBackend(
      explicitBaseUrl: _config['api_base_url']?.toString(),
    );
    if (!mounted) return;
    setState(() {
      _systemStatus = _buildBackendStatusLine(health);
    });
  }

  Future<void> _bootstrapApp() async {
    await _restoreLocalState();
    await _refreshBackendConnection();
    await _refreshAdminState();
    await _loadMusicLibrary();
    await _loadReminders();
    await _refreshJarvisFoundation();
    if (!mounted) return;
    _refreshOpeningLine();
  }

  String _periodGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _resolvedUserName() {
    final preferred = (_config['nome_usuario']?.toString().trim() ?? '');
    if (preferred.isNotEmpty) return preferred;
    for (final user in _users) {
      final active = user['ativo'];
      if (active == false) continue;
      final name = user['nome']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Gabriel';
  }

  String _activeProjectLabel() {
    const hints = ['nova', 'projeto', 'flutter', 'interface', 'app'];
    for (final item in _recentMemory) {
      final content = item['content']?.toString().trim() ?? '';
      if (content.isEmpty) continue;
      final lowered = content.toLowerCase();
      if (hints.any(lowered.contains)) {
        return _truncateRailText(content, limit: 42);
      }
    }
    for (final note in _brainNotes) {
      final title = note['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      final lowered = title.toLowerCase();
      if (hints.any(lowered.contains)) {
        return _truncateRailText(title, limit: 38);
      }
    }
    return 'projeto NOVA';
  }

  String _conversationContextLabel() {
    final project = _activeProjectLabel();
    final attachmentName = _composerAttachment?.name.trim() ?? '';
    if (attachmentName.isNotEmpty) {
      return 'Contexto ativo: $project · anexo pronto para análise';
    }
    if (_recentMemory.isNotEmpty) {
      return 'Contexto ativo: $project · memória operacional sincronizada';
    }
    return 'Contexto ativo: $project · pronto para sugerir e executar';
  }

  String _contextualGreetingHeadline() {
    final name = _resolvedUserName();
    final project = _activeProjectLabel();
    return '${_periodGreeting()}, $name. Vi que voce estava trabalhando em $project.';
  }

  String _contextualGreetingBriefing() {
    final hasMemories = _recentMemory.isNotEmpty;
    final notesCount =
        (_brainGraph['total_notes'] as num?)?.toInt() ?? _brainNotes.length;
    if (hasMemories) {
      return 'Quer continuar de onde parou, revisar melhorias ou transformar isso em um proximo passo executavel?'
          ' Eu ja separei memoria, sugestoes e historico para acelerar a retomada.';
    }
    if (notesCount > 0) {
      return 'Ja encontrei $notesCount nota${notesCount == 1 ? '' : 's'} para apoiar a retomada.'
          ' Posso organizar o contexto, sugerir a melhor acao ou executar o proximo passo.';
    }
    return 'A NOVA nao funciona como um chat solto.'
        ' Ela entende contexto, sugere caminhos, executa tarefas e aprende com o seu jeito de trabalhar.';
  }

  String _jarvisUserId() {
    final named = (_config['nome_usuario']?.toString().trim() ?? '');
    if (named.isNotEmpty) return named;
    return 'frontend';
  }

  String _truncateRailText(String text, {int limit = 82}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) return normalized;
    final cut = normalized.substring(0, limit);
    final safe =
        cut.contains(' ') ? cut.substring(0, cut.lastIndexOf(' ')) : cut;
    return '${safe.trim()}...';
  }

  List<String> _memoryRailItems() {
    return _recentMemory
        .map((item) {
          final category = item['category']?.toString().trim() ?? 'contexto';
          final content = item['content']?.toString().trim() ?? '';
          if (content.isEmpty) return '';
          return '${category.toUpperCase()}: ${_truncateRailText(content)}';
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  NovaChatLine? _lastAssistantLine() {
    for (var index = _chat.length - 1; index >= 0; index--) {
      final item = _chat[index];
      if (!item.fromUser) return item;
    }
    return null;
  }

  Future<void> _copyGeneratedCode(NovaChatLine line) async {
    final code = line.copyText?.trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codigo copiado para a area de transferencia.'),
      ),
    );
  }

  Future<void> _previewGeneratedCode(NovaChatLine line) async {
    final code = line.copyText?.trim() ?? '';
    if (code.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.novaColors;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GlassContainer(
            borderRadius: 30,
            blur: 28,
            opacity: dialogContext.isNovaDark ? 0.18 : 0.34,
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 820,
                maxHeight: 620,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Preview do codigo',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    line.summary?.trim().isNotEmpty == true
                        ? line.summary!.trim()
                        : 'Codigo gerado pela NOVA.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.6,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          code,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.2,
                            height: 1.55,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!dialogContext.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Codigo copiado para a area de transferencia.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Copiar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_NovaDevLanguageOption> _devLanguageOptions() {
    return const [
      _NovaDevLanguageOption(label: 'Auto', value: ''),
      _NovaDevLanguageOption(label: 'HTML/CSS/JS', value: 'html_css_js'),
      _NovaDevLanguageOption(label: 'JavaScript', value: 'javascript'),
      _NovaDevLanguageOption(label: 'Python', value: 'python'),
      _NovaDevLanguageOption(label: 'Java', value: 'java'),
      _NovaDevLanguageOption(label: 'C++', value: 'cpp'),
    ];
  }

  String _devPromptSeed() {
    final lastAssistant = _lastAssistantLine();
    final base = lastAssistant?.explanation?.trim().isNotEmpty == true
        ? lastAssistant!.explanation!.trim()
        : lastAssistant?.text.trim() ?? '';
    if (base.isEmpty) return '';
    return 'Crie codigo com base neste contexto: ${_summarizeText(base, limit: 120)}';
  }

  Future<_NovaDevGeneratorRequest?> _showDevGeneratorDialog({
    String initialPrompt = '',
  }) async {
    final promptController = TextEditingController(text: initialPrompt);
    final projectController = TextEditingController();
    var selectedLanguage = '';

    final result = await showDialog<_NovaDevGeneratorRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final colors = dialogContext.novaColors;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: GlassContainer(
                borderRadius: 30,
                blur: 28,
                opacity: dialogContext.isNovaDark ? 0.18 : 0.34,
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modulo Dev',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Descreva a ideia e a NOVA gera uma base real de codigo com instrucoes de execucao.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13.8,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: promptController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Ideia do projeto',
                          hintText:
                              'Ex: criar uma tela de login moderna, uma API em Python ou um script de automacao.',
                          filled: true,
                          fillColor: Colors.white.withValues(
                            alpha: dialogContext.isNovaDark ? 0.07 : 0.76,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _devLanguageOptions()
                            .map(
                              (option) => ChoiceChip(
                                label: Text(option.label),
                                selected: selectedLanguage == option.value,
                                onSelected: (_) {
                                  setDialogState(() {
                                    selectedLanguage = option.value;
                                  });
                                },
                                selectedColor:
                                    colors.primarySoft.withValues(alpha: 0.24),
                                backgroundColor: Colors.white.withValues(
                                  alpha: dialogContext.isNovaDark ? 0.06 : 0.64,
                                ),
                                side: BorderSide(
                                  color: selectedLanguage == option.value
                                      ? colors.primary
                                      : colors.glassBorder,
                                ),
                                labelStyle: TextStyle(
                                  color: selectedLanguage == option.value
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: projectController,
                        decoration: InputDecoration(
                          labelText: 'Nome da pasta (opcional)',
                          hintText: 'Ex: login_premium',
                          filled: true,
                          fillColor: Colors.white.withValues(
                            alpha: dialogContext.isNovaDark ? 0.07 : 0.76,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: colors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () {
                              final prompt = promptController.text.trim();
                              if (prompt.isEmpty) return;
                              Navigator.of(dialogContext).pop(
                                _NovaDevGeneratorRequest(
                                  prompt: prompt,
                                  language: selectedLanguage,
                                  projectName: projectController.text.trim(),
                                ),
                              );
                            },
                            child: const Text('Gerar codigo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    promptController.dispose();
    projectController.dispose();
    return result;
  }

  Future<void> _openDevGeneratorFlow({
    String initialPrompt = '',
  }) async {
    final request = await _showDevGeneratorDialog(initialPrompt: initialPrompt);
    if (request == null) return;

    setState(() {
      _chat.add(
        NovaChatLine(
          fromUser: true,
          text: 'Gerar codigo: ${request.prompt}',
        ),
      );
      _sending = true;
      _assistantState = NovaAssistantState.executing;
      _systemStatus = 'Modulo Dev gerando codigo...';
    });

    try {
      final payload = await _api.generateDevCode(
        prompt: request.prompt,
        language: request.language,
        projectName: request.projectName,
        autoConfirm: true,
      );
      if (!mounted) return;
      final assistantLine = _assistantLineFromPayload(request.prompt, payload);
      final projectRef = payload['project_ref']?.toString().trim() ?? '';
      setState(() {
        _chat.add(assistantLine);
        _assistantState = NovaAssistantState.suggesting;
        _systemStatus = projectRef.isNotEmpty
            ? 'Codigo gerado em $projectRef.'
            : 'Codigo gerado pelo modulo Dev.';
      });
    } catch (error) {
      if (!mounted) return;
      final message = _humanizeApiError(
        error,
        fallback: 'Nao consegui gerar esse codigo agora.',
      );
      setState(() {
        _chat.add(
          NovaChatLine(
            fromUser: false,
            text: message,
            summary: 'Falha ao gerar codigo.',
            explanation: message,
            actions: _defaultConversationActions(),
            state: NovaAssistantState.responding,
          ),
        );
        _assistantState = NovaAssistantState.responding;
        _systemStatus = 'Falha no modulo Dev.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          if (_assistantState == NovaAssistantState.responding) {
            _assistantState = NovaAssistantState.idle;
          }
        });
      }
    }
  }

  List<String> _extractStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((item) {
          if (item is String) return item.trim();
          if (item is Map) {
            final label = item['label']?.toString().trim() ?? '';
            if (label.isNotEmpty) return label;
            final text = item['text']?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _summarizeText(String text, {int limit = 180}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) return normalized;
    final clipped = normalized.substring(0, limit);
    final safe = clipped.contains(' ')
        ? clipped.substring(0, clipped.lastIndexOf(' '))
        : clipped;
    return '${safe.trim()}...';
  }

  IconData _iconForActionLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('codigo')) return Icons.code_rounded;
    if (normalized.contains('interface')) return Icons.design_services_rounded;
    if (normalized.contains('continuar')) return Icons.arrow_forward_rounded;
    if (normalized.contains('memoria') || normalized.contains('salvar')) {
      return Icons.bookmark_outline_rounded;
    }
    if (normalized.contains('pesquisa') || normalized.contains('fontes')) {
      return Icons.travel_explore_rounded;
    }
    if (normalized.contains('lembrete') || normalized.contains('agenda')) {
      return Icons.alarm_rounded;
    }
    if (normalized.contains('automat')) return Icons.bolt_rounded;
    return Icons.auto_awesome_rounded;
  }

  String _promptForActionLabel(String label) {
    final normalized = label.toLowerCase();
    final project = _activeProjectLabel();

    if (normalized.contains('continuar projeto')) {
      return 'Continuar o projeto $project e me mostrar o proximo passo operacional.';
    }
    if (normalized.contains('continuar daqui')) {
      return 'Continue de onde paramos e organize o proximo passo mais importante.';
    }
    if (normalized.contains('gerar codigo')) {
      return 'Gerar codigo para o contexto atual e explicar como aplicar.';
    }
    if (normalized.contains('melhorar interface')) {
      return 'Melhorar a interface atual da NOVA com foco em fluidez e percepcao premium.';
    }
    if (normalized.contains('explicar codigo')) {
      return 'Explique o codigo gerado, a estrutura dos arquivos e como posso evoluir isso.';
    }
    if (normalized.contains('corrigir codigo')) {
      return 'Analise o codigo atual, encontre o erro e sugira a correcao mais segura.';
    }
    if (normalized.contains('organizar') ||
        normalized.contains('proximo passo')) {
      return 'Organize os proximos passos desta conversa em ordem de prioridade.';
    }
    if (normalized.contains('salvar contexto') ||
        normalized.contains('salvar resumo') ||
        normalized.contains('salvar na memoria')) {
      return 'Salvar o contexto importante desta conversa na memoria da NOVA.';
    }
    if (normalized.contains('comparar fontes')) {
      return 'Compare as fontes e destaque o que realmente importa.';
    }
    if (normalized.contains('aprofundar pesquisa')) {
      return 'Aprofunde a pesquisa e traga uma resposta mais robusta.';
    }
    if (normalized.contains('criar lembrete')) {
      return 'Crie um lembrete com base no que estamos tratando agora.';
    }
    if (normalized.contains('automatizar')) {
      return 'Mostre como automatizar isso daqui para frente.';
    }
    if (normalized.contains('revisar a acao')) {
      return 'Revise a acao proposta e explique o impacto antes de executar.';
    }
    if (normalized.contains('explicar o impacto')) {
      return 'Explique o impacto dessa acao e os riscos antes de continuar.';
    }
    return label;
  }

  List<NovaConversationAction> _actionObjectsFromLabels(
    List<String> labels, {
    bool firstPrimary = true,
  }) {
    final used = <String>{};
    final actions = <NovaConversationAction>[];
    for (final label in labels) {
      final clean = label.trim();
      final key = clean.toLowerCase();
      if (clean.isEmpty || used.contains(key)) continue;
      used.add(key);
      actions.add(
        NovaConversationAction(
          label: clean,
          prompt: _promptForActionLabel(clean),
          primary: firstPrimary && actions.isEmpty,
          icon: _iconForActionLabel(clean),
        ),
      );
    }
    return actions;
  }

  List<NovaConversationAction> _defaultConversationActions() {
    return _actionObjectsFromLabels(
      const [
        'Organizar próximo passo',
        'Comparar fontes',
        'Criar lembrete',
      ],
    );
  }

  NovaChatLine _buildGreetingLine() {
    return NovaChatLine(
      fromUser: false,
      text: _contextualGreetingBriefing(),
      summary: _contextualGreetingHeadline(),
      explanation: _contextualGreetingBriefing(),
      actions: _actionObjectsFromLabels(
        const [
          'Organizar próximo passo',
          'Abrir memoria e notas',
          'Criar lembrete',
        ],
      ),
      suggestions: _actionObjectsFromLabels(
        const [
          'Comparar fontes',
          'Salvar na memoria',
          'Criar lembrete',
        ],
        firstPrimary: false,
      ),
      state: NovaAssistantState.suggesting,
      highlight: true,
    );
  }

  void _refreshOpeningLine() {
    final greetingLine = _buildGreetingLine();
    if (_chat.isEmpty) {
      setState(() => _chat.add(greetingLine));
      return;
    }
    setState(() {
      if (_chat.first.fromUser) {
        _chat.insert(0, greetingLine);
      } else {
        _chat[0] = greetingLine;
      }
    });
  }

  NovaChatLine _pinnedConversationLine() {
    return _lastAssistantLine() ?? _buildGreetingLine();
  }

  List<NovaChatLine> _visibleChatLines() {
    if (_chat.isEmpty) return const [];
    if (!_chat.first.fromUser) {
      return _chat.skip(1).toList();
    }
    return List<NovaChatLine>.from(_chat);
  }

  NovaAssistantState _assistantStateFromPayload(Map<String, dynamic> payload) {
    final raw =
        payload['assistant_state']?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'thinking':
        return NovaAssistantState.thinking;
      case 'responding':
        return NovaAssistantState.responding;
      case 'suggesting':
        return NovaAssistantState.suggesting;
      case 'executing':
        return NovaAssistantState.executing;
      default:
        break;
    }
    if (payload['decision_type']?.toString().trim() == 'tool_call') {
      return NovaAssistantState.executing;
    }
    return NovaAssistantState.responding;
  }

  Map<String, dynamic> _buildLocalStructuredPayload(
    String userMessage,
    String reply,
  ) {
    final operational = userMessage.toLowerCase().contains('abrir') ||
            userMessage.toLowerCase().contains('mostrar') ||
            userMessage.toLowerCase().contains('salvar')
        ? 'Executando'
        : 'Respondendo';

    return {
      'reply': reply,
      'resumo': _summarizeText(reply, limit: 140),
      'explicacao': reply,
      'acoes': const [
        'Continuar daqui',
        'Organizar próximo passo',
        'Salvar contexto',
      ],
      'sugestoes': const [
        'Organizar próximo passo',
        'Comparar fontes',
        'Criar lembrete',
      ],
      'assistant_state': operational.toLowerCase(),
    };
  }

  NovaChatLine _assistantLineFromPayload(
    String userMessage,
    Map<String, dynamic> payload,
  ) {
    final reply = payload['reply']?.toString().trim().isNotEmpty == true
        ? payload['reply'].toString().trim()
        : (payload['answer']?.toString().trim().isNotEmpty == true
            ? payload['answer'].toString().trim()
            : (payload['explicacao']?.toString().trim().isNotEmpty == true
                ? payload['explicacao'].toString().trim()
                : 'Sem resposta.'));
    final summary = payload['resumo']?.toString().trim().isNotEmpty == true
        ? payload['resumo'].toString().trim()
        : _summarizeText(reply, limit: 150);
    final explanation =
        payload['explicacao']?.toString().trim().isNotEmpty == true
            ? payload['explicacao'].toString().trim()
            : reply;
    final actionLabels = _extractStringList(
      payload['acoes'] is List ? payload['acoes'] : payload['next_actions'],
    );
    final suggestionLabels = _extractStringList(
      payload['sugestoes'] is List
          ? payload['sugestoes']
          : payload['next_actions'],
    );
    final actions = actionLabels.isNotEmpty
        ? _actionObjectsFromLabels(actionLabels)
        : _defaultConversationActions();
    final suggestions = suggestionLabels.isNotEmpty
        ? _actionObjectsFromLabels(suggestionLabels, firstPrimary: false)
        : _actionObjectsFromLabels(
            const [
              'Continuar daqui',
              'Organizar próximo passo',
              'Salvar contexto',
            ],
            firstPrimary: false,
          );

    final state = _assistantStateFromPayload(payload);
    final highlighted = userMessage.toLowerCase().contains('nova') &&
        (reply.toLowerCase().contains('projeto') ||
            summary.toLowerCase().contains('contexto'));

    return NovaChatLine(
      fromUser: false,
      text: reply,
      summary: summary,
      explanation: explanation,
      copyText: payload['code_bundle']?.toString().trim().isNotEmpty == true
          ? payload['code_bundle'].toString().trim()
          : null,
      copyLabel: payload['copy_label']?.toString().trim().isNotEmpty == true
          ? payload['copy_label'].toString().trim()
          : null,
      actions: actions,
      suggestions: suggestions,
      state: state,
      highlight: highlighted,
    );
  }

  List<String> _documentHighlights() {
    final docs = <String>[];
    final attachmentName = _composerAttachment?.name.trim() ?? '';
    if (attachmentName.isNotEmpty) {
      docs.add('Anexo atual: $attachmentName');
    }
    final attachmentSummary = _composerAttachment?.summary.trim() ?? '';
    if (attachmentSummary.isNotEmpty) {
      docs.add('Análise: ${_summarizeText(attachmentSummary, limit: 72)}');
    }
    for (final note in _brainNotes.take(3)) {
      final title = note['title']?.toString().trim() ?? '';
      if (title.isNotEmpty) docs.add('Vault: $title');
    }
    return docs;
  }

  List<NovaModuleSnapshot> _contextModules() {
    final combinedText = [
      for (final item in _chat.take(8))
        item.summary?.toLowerCase() ?? item.text.toLowerCase(),
      ..._memoryRailItems().map((item) => item.toLowerCase()),
    ].join(' ');

    bool containsAny(List<String> tokens) =>
        tokens.any((token) => combinedText.contains(token));

    return [
      NovaModuleSnapshot(
        title: 'Cerebro',
        description: 'Memoria, contexto e preferencias sempre a vista.',
        metric: '${_recentMemory.length} ctx',
        icon: Icons.psychology_alt_rounded,
        active: _recentMemory.isNotEmpty || _brainNotes.isNotEmpty,
      ),
      NovaModuleSnapshot(
        title: 'Dev',
        description: 'Codigo, interface e entregas do produto em andamento.',
        metric: containsAny(['codigo', 'flutter', 'interface', 'bug'])
            ? 'ativo'
            : 'pronto',
        icon: Icons.code_rounded,
        active:
            containsAny(['codigo', 'flutter', 'interface', 'bug', 'projeto']),
      ),
      NovaModuleSnapshot(
        title: 'Pesquisa',
        description: 'Fontes, comparacoes e leitura acelerada.',
        metric:
            containsAny(['pesquisa', 'fonte', 'resumo']) ? 'quente' : 'pronto',
        icon: Icons.travel_explore_rounded,
        active: containsAny(['pesquisa', 'fonte', 'resumo']),
      ),
      NovaModuleSnapshot(
        title: 'Financeiro',
        description: 'Custos, previsoes e decisao por numeros.',
        metric: containsAny(['finance', 'orcamento', 'receita', 'custo'])
            ? 'em foco'
            : 'standby',
        icon: Icons.account_balance_wallet_rounded,
        active: containsAny(['finance', 'orcamento', 'receita', 'custo']),
      ),
      NovaModuleSnapshot(
        title: 'Automacao',
        description: 'Execucao segura de acoes e proximos passos.',
        metric: _assistantState == NovaAssistantState.executing
            ? 'rodando'
            : 'pronta',
        icon: Icons.bolt_rounded,
        active: _assistantState == NovaAssistantState.executing ||
            _reminders.isNotEmpty,
      ),
    ];
  }

  Future<void> _refreshJarvisFoundation() async {
    Map<String, dynamic> jarvisStatus = _jarvisStatus;
    Map<String, dynamic> voiceStatus = _voiceStatus;
    List<Map<String, dynamic>> tools = _jarvisTools;
    List<Map<String, dynamic>> recentMemory = _recentMemory;
    List<Map<String, dynamic>> brainNotes = _brainNotes;
    List<Map<String, dynamic>> brainSuggestions = _brainSuggestions;
    Map<String, dynamic> brainGraph = _brainGraph;

    try {
      jarvisStatus = await _api.getJarvisStatus();
    } catch (_) {}

    try {
      voiceStatus = await _api.getVoiceStatus();
    } catch (_) {}

    try {
      tools = await _api.getJarvisTools();
    } catch (_) {}

    try {
      final workspace = await _memoryService.loadWorkspaceSnapshot(
        userId: _jarvisUserId(),
      );
      recentMemory =
          (workspace['recent_memories'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      brainNotes = (workspace['notes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      brainSuggestions =
          (workspace['suggestions'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      brainGraph = (workspace['graph'] is Map)
          ? Map<String, dynamic>.from(workspace['graph'] as Map)
          : brainGraph;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _jarvisStatus = jarvisStatus;
      _voiceStatus = voiceStatus;
      _jarvisTools = tools;
      _recentMemory = recentMemory;
      _brainNotes = brainNotes;
      _brainSuggestions = brainSuggestions;
      _brainGraph = brainGraph;
    });
  }

  Future<Uint8List> _buildDocumentReportPdf({
    required String reportText,
    required String fileName,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now().toIso8601String();
    final sanitized = fileName.trim().isEmpty ? 'documento' : fileName.trim();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.openSansRegular(),
            bold: await PdfGoogleFonts.openSansBold(),
          ),
        ),
        build: (context) => [
          pw.Text(
            'NOVA • Relatório de Documento',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Arquivo: $sanitized',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text('Gerado em: $now',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue200),
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              reportText.trim().isEmpty
                  ? 'Relatório vazio.'
                  : reportText.trim(),
              style: const pw.TextStyle(
                fontSize: 11.5,
                lineSpacing: 2,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat.add(_buildGreetingLine());
    _initTts();
    _initSpeech();
    _notifications.init();
    _bootstrapApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    _audioPlayer.dispose();
    _voicePlayer.dispose();
    BackgroundWakeService.stop();
    _localDb.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!PlatformCapabilities.isAndroid) return;

    if (state == AppLifecycleState.resumed) {
      BackgroundWakeService.stop();
      if (_listenModeEnabled && _effectiveContinuousWake && !_isListening) {
        _manualListeningStop = false;
        _startListening();
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_listenModeEnabled && _effectiveContinuousWake) {
        _manualListeningStop = true;
        _speech.stop();
        final wake = _config['wake_word']?.toString() ?? 'nova';
        final allow = _config['allow_voice_on_lock'] != false;
        BackgroundWakeService.start(
          wakeWord: wake,
          allowVoiceOnLock: allow,
        );
      }
    }
  }

  Future<void> _restoreLocalState() async {
    try {
      final decoded = await _localDb.loadAdminState();
      final secureConfig = await _secureSecrets.readConfigSecrets();

      final knowledge = decoded['knowledge'];
      final users = decoded['users'];
      final config = decoded['config'];

      if (!mounted) return;
      setState(() {
        if (knowledge is List) {
          _knowledge = knowledge
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (users is List) {
          _users = users
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
        if (config is Map) {
          _config = {
            ..._config,
            ...Map<String, dynamic>.from(config),
            ...secureConfig,
          };
          _continuousWakeMode = _config['continuous_wake'] != false;
          if (_pushToTalkOnly) {
            _continuousWakeMode = false;
          }
        }
      });
      _syncApiConnectionSettingsFromConfig();
      if (!_listenModeEnabled) {
        _manualListeningStop = true;
        await _speech.stop();
        await BackgroundWakeService.stop();
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
    } catch (_) {
      // Ignora estado local inválido.
    }
  }

  Future<void> _saveLocalState() async {
    await _secureSecrets.saveConfigSecrets(
      telegramToken: _config['telegram_token']?.toString() ?? '',
      telegramChatId: _config['telegram_chat_id']?.toString() ?? '',
      apiToken: _config['api_token']?.toString() ?? '',
    );

    final sanitizedConfig = Map<String, dynamic>.from(_config)
      ..remove('telegram_token')
      ..remove('telegram_chat_id')
      ..remove('api_token');

    await _localDb.saveAdminState(
      knowledge: _knowledge,
      users: _users,
      config: sanitizedConfig,
    );
  }

  Future<void> _refreshAdminState() async {
    if (_loadingState) return;
    _loadingState = true;
    try {
      final payload = await _api.getAdminState();
      final state = payload['state'];
      if (state is Map) {
        if (!mounted) return;
        setState(() {
          _knowledge = (state['knowledge'] is List)
              ? (state['knowledge'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : _knowledge;
          _users = (state['users'] is List)
              ? (state['users'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : _users;
          _config = (state['config'] is Map)
              ? {
                  ..._config,
                  ...Map<String, dynamic>.from(state['config']),
                }
              : _config;
          _continuousWakeMode = _config['continuous_wake'] != false;
          if (_pushToTalkOnly) {
            _continuousWakeMode = false;
          }
          _systemStatus = 'Painel sincronizado com backend.';
        });
        _syncApiConnectionSettingsFromConfig();
        await _saveLocalState();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _systemStatus =
            'Sem conexão com backend em ${_api.baseUrl}. Usando dados locais do celular.';
      });
    } finally {
      _loadingState = false;
    }
  }

  Future<void> _loadMusicLibrary() async {
    if (!PlatformCapabilities.supportsLocalMusicLibrary) {
      if (!mounted) return;
      setState(() => _musicLibrary = []);
      return;
    }
    try {
      final items = await _localDb.getMusicLibrary();
      if (!mounted) return;
      setState(() => _musicLibrary = items);
    } catch (_) {
      // ignora falha local
    }
  }

  Future<void> _loadReminders() async {
    try {
      final items = await _api.getReminders();
      if (!mounted) return;
      setState(() => _reminders = items);
      await _syncReminderNotifications(items);
      try {
        await _localDb.saveReminders(items);
      } catch (_) {
        // Em plataformas sem DB local (ex.: web), mantém dados do backend.
      }
      return;
    } catch (_) {
      // fallback local apenas se backend falhar
    }
    try {
      final localItems = await _localDb.getReminders();
      if (!mounted) return;
      setState(() => _reminders = localItems);
      await _syncReminderNotifications(localItems);
    } catch (_) {
      // mantém último estado em memória
    }
  }

  int _notificationIdFromReminderId(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  DateTime? _parseReminderWhen(String raw) {
    final txt = raw.trim();
    if (txt.isEmpty) return null;
    try {
      return DateTime.parse(txt).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncReminderNotifications(
      List<Map<String, dynamic>> items) async {
    for (final item in items) {
      final id = (item['id'] ?? '').toString().trim();
      final texto = (item['texto'] ?? '').toString().trim();
      final whenRaw = (item['quando'] ?? '').toString();
      if (id.isEmpty || texto.isEmpty) continue;
      final when = _parseReminderWhen(whenRaw);
      if (when == null) continue;
      final now = DateTime.now();
      if (!when.isAfter(now)) continue;
      final notifId = _notificationIdFromReminderId(id);
      try {
        await _notifications.scheduleReminder(
          id: notifId,
          title: 'Lembrete da NOVA',
          body: texto,
          when: when,
        );
      } catch (_) {
        // segue sem interromper UX
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _selecionarEngineEVozMaisNatural();
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(kIsWeb ? 0.52 : 0.50);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  bool get _ttsEnabled => _config['voz_ativa'] == true;

  Future<void> _selecionarEngineEVozMaisNatural() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.isNotEmpty) {
        final lista = engines.map((e) => e.toString()).toList();
        String? escolhida;
        for (final engine in lista) {
          final l = engine.toLowerCase();
          if (l.contains('samsung') ||
              l.contains('vocalizer') ||
              l.contains('acapela')) {
            escolhida = engine;
            break;
          }
        }
        escolhida ??= lista.firstWhere(
          (e) => !e.toLowerCase().contains('google'),
          orElse: () => lista.first,
        );
        await _tts.setEngine(escolhida);
      }
    } catch (_) {
      // Alguns dispositivos não permitem trocar engine por app.
    }

    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;

      final preferidas = [
        'pt-br',
        'portuguese',
        'portugues',
        'natural',
        'online',
        'enhanced',
        'microsoft',
        'francisca',
        'helena',
        'maria',
        'luciana',
        'vitoria',
        'female',
        'woman',
        'feminina',
        'premium',
        'network',
        'neural',
        'wavenet',
      ];
      final evitar = ['male', 'masculina', 'masculino'];

      Map<dynamic, dynamic>? melhor;
      int melhorScore = -9999;

      for (final raw in voices) {
        if (raw is! Map) continue;
        final voice = raw.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        final nome = (voice['name'] ?? '').toLowerCase();
        final locale =
            ((voice['locale'] ?? voice['language'] ?? '')).toLowerCase();
        final gender = (voice['gender'] ?? '').toLowerCase();

        if (!(locale.contains('pt-br') || locale.contains('pt_br'))) continue;

        int score = 0;
        if (locale.contains('pt-br') || locale.contains('pt_br')) score += 8;
        if (gender.contains('female') || gender.contains('femin')) score += 9;
        for (final item in preferidas) {
          if (nome.contains(item)) score += 5;
        }
        for (final item in evitar) {
          if (nome.contains(item)) score -= 12;
        }
        if (nome.contains('google')) score -= 8;

        if (score > melhorScore) {
          melhor = raw;
          melhorScore = score;
        }
      }

      if (melhor != null) {
        final nome = melhor['name']?.toString();
        final locale = (melhor['locale'] ?? melhor['language'])?.toString();
        if (nome != null && locale != null) {
          await _tts.setVoice({'name': nome, 'locale': locale});
        }
      }
    } catch (_) {
      // Mantém voz padrão quando API do dispositivo é limitada.
    }
  }

  String _textoMaisHumanoParaFala(String text) {
    return SpeechFormatter.prepareForSpeech(text);
  }

  List<String> _quebrarEmBlocosDeFala(String text, {int maxChars = 420}) {
    if (text.length <= maxChars) return [text];
    final partes = text.split(RegExp(r'(?<=[.!?])\s+'));
    final blocos = <String>[];
    var buffer = '';
    for (final p in partes) {
      final item = p.trim();
      if (item.isEmpty) continue;
      if ((buffer.length + item.length + 1) <= maxChars) {
        buffer = buffer.isEmpty ? item : '$buffer $item';
      } else {
        if (buffer.isNotEmpty) blocos.add(buffer);
        buffer = item;
      }
    }
    if (buffer.isNotEmpty) blocos.add(buffer);
    return blocos.isEmpty ? [text] : blocos;
  }

  bool get _neuralVoiceHybridEnabled => _config['voice_neural_hybrid'] != false;

  Future<bool> _speakNeuralOnline(String text, int requestId) async {
    final profile =
        (_config['voice_profile']?.toString().trim().toLowerCase() ??
                'feminina')
            .replaceAll(' ', '');
    final payload = await _api.synthesizeNeuralVoice(
      text,
      voiceProfile: profile.isEmpty ? 'feminina' : profile,
    );
    final b64 = payload['audio_base64']?.toString() ?? '';
    if (b64.isEmpty) return false;
    Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      return false;
    }
    if (bytes.isEmpty) return false;
    if (requestId != _speakRequestId) return false;
    await _voicePlayer.stop();
    if (requestId != _speakRequestId) return false;
    await _voicePlayer.play(BytesSource(bytes));
    return true;
  }

  Future<void> _speak(String text) async {
    if (!_ttsEnabled) return;
    final requestId = ++_speakRequestId;
    final clean = _textoMaisHumanoParaFala(text);
    if (clean.isEmpty) return;
    final textoVoz =
        clean.length > 900 ? '${clean.substring(0, 900)}...' : clean;
    await _voicePlayer.stop();
    await _tts.stop();

    if (_neuralVoiceHybridEnabled) {
      try {
        final ok = await _speakNeuralOnline(textoVoz, requestId);
        if (ok) {
          if (mounted) {
            setState(() {
              _systemStatus = 'Voz neural online ativa.';
            });
          }
          return;
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _systemStatus = 'Voz neural indisponível, usando voz local.';
          });
        }
      }
    }

    if (requestId != _speakRequestId) return;
    if (mounted) {
      setState(() {
        _systemStatus = 'Usando voz local do dispositivo.';
      });
    }
    final blocos = _quebrarEmBlocosDeFala(textoVoz);
    for (final bloco in blocos) {
      if (requestId != _speakRequestId) break;
      await _tts.speak(bloco);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> _initSpeech() async {
    if (!_listenModeEnabled) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _isListening = false;
        _systemStatus = 'Modo escuta desativado.';
      });
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_listenModeEnabled &&
              _effectiveContinuousWake &&
              !_manualListeningStop) {
            Future<void>.delayed(const Duration(milliseconds: 250), () {
              if (!mounted || _isListening || !_speechReady) return;
              _startListening();
            });
          }
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _systemStatus = 'Falha no microfone.';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _speechReady = available;
      _systemStatus = available ? 'Tudo pronto.' : 'Microfone indisponível.';
    });
    if (available && _listenModeEnabled && _effectiveContinuousWake) {
      _startListening();
    }
  }

  Future<void> _finalizarEscutaEProcessarVoz(String words) async {
    _manualListeningStop = true;
    try {
      await _speech.stop();
    } catch (_) {
      // Falha de parada não deve bloquear o envio por voz.
    }
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _systemStatus = 'Comando de voz capturado.';
    });
    await _handleWakeWordVoice(words);
  }

  Future<void> _startListening() async {
    if (!_listenModeEnabled) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _systemStatus = 'Modo escuta desativado.';
      });
      return;
    }
    if (!_speechReady) return;
    _manualListeningStop = false;
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _executedFromVoice = false;
      _systemStatus = 'Estou ouvindo você...';
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        _messageController.text = words;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );

        if (result.finalResult && words.isNotEmpty && !_executedFromVoice) {
          _executedFromVoice = true;
          _finalizarEscutaEProcessarVoz(words);
        }
      },
    );
  }

  Future<void> _toggleListening() async {
    if (!_listenModeEnabled) {
      if (!mounted) return;
      setState(() => _systemStatus = 'Ative o modo escuta nas configurações.');
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) return;
    }

    if (_isListening) {
      _manualListeningStop = true;
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _systemStatus = 'Escuta pausada.';
      });
      return;
    }

    await _startListening();
  }

  Future<void> _handleWakeWordVoice(String words) async {
    final wakeWord =
        (_config['wake_word']?.toString().trim().toLowerCase() ?? 'nova');
    if (wakeWord.isEmpty) return;

    final cleaned = words.trim();
    if (cleaned.isEmpty) return;

    final lower = _normalizarParaMatch(cleaned);
    final wake = _normalizarParaMatch(wakeWord);
    final temWake = RegExp(r'\b' + RegExp.escape(wake) + r'\b').hasMatch(lower);

    if (!temWake) {
      // Quando o usuário toca no microfone manualmente, aceita frases naturais longas sem wake word.
      if (lower.split(' ').length >= 4) {
        final comandoSemWake = _limparComandoDeVoz(cleaned);
        await _executeCommand(comandoSemWake, fromVoice: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _systemStatus =
            'Diga "$wakeWord" para ativar, ou fale um comando completo.';
      });
      return;
    }

    final command = _extrairComandoAposWakeWord(cleaned, wakeWord);

    if (command.isEmpty) {
      const ack = 'Oi chefe.';
      if (!mounted) return;
      setState(() {
        _chat.add(
          NovaChatLine(
            fromUser: false,
            text: ack,
            summary: 'Pronta para continuar.',
            explanation: ack,
            actions: _defaultConversationActions(),
            suggestions: _actionObjectsFromLabels(
              const [
                'Organizar próximo passo',
                'Salvar na memoria',
                'Criar lembrete',
              ],
              firstPrimary: false,
            ),
            state: NovaAssistantState.suggesting,
          ),
        );
        _systemStatus = 'Wake word detectada.';
        _assistantState = NovaAssistantState.suggesting;
      });
      await _speak(ack);
      return;
    }

    await _executeCommand(_limparComandoDeVoz(command), fromVoice: true);
  }

  String _normalizarParaMatch(String input) {
    var t = input.toLowerCase();
    const mapa = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    mapa.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll(RegExp(r'[^\w\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  String _extrairComandoAposWakeWord(String frase, String wakeWord) {
    final pattern = RegExp(
      r'(?:^|\s)(?:ei|hey|ok|okay|ola|olá)?\s*' +
          RegExp.escape(wakeWord) +
          r'[:,]?\s*',
      caseSensitive: false,
    );
    return frase.replaceFirst(pattern, '').trim();
  }

  String _limparComandoDeVoz(String comando) {
    var t = comando.trim();
    t = t.replaceFirst(
      RegExp(
        r'^(por favor|por gentileza|pode|você pode|voce pode|consegue|quero que você|quero que voce)\s+',
        caseSensitive: false,
      ),
      '',
    );
    t = t.replaceFirst(
      RegExp(r'^(pra mim|para mim)\s+', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  String _attachmentContextForChat(NovaAttachment? attachment) {
    if (attachment == null) return '';
    final details = <String>[
      'Arquivo anexado: ${attachment.name}',
      'Tipo MIME: ${attachment.mimeType}',
    ];
    final summary = attachment.summary.trim();
    if (summary.isNotEmpty) {
      details.add('Resumo da análise: $summary');
    }
    return details.join('\n');
  }

  Future<void> _handleSendMessage() async {
    final message = _messageController.text.trim();
    final attachment = _composerAttachment;
    if (message.isEmpty && attachment == null) return;
    final outbound = message.isNotEmpty
        ? message
        : attachment!.isImage
            ? 'NOVA, analise esta imagem.'
            : 'NOVA, leia e resuma este documento.';
    await _executeCommand(
      outbound,
      fromVoice: false,
      attachment: attachment,
    );
    if (!mounted) return;
    setState(() {
      _composerAttachment = null;
    });
  }

  Future<void> _prepareAttachment(
    NovaAttachment attachment, {
    String successMessage = 'Arquivo anexado com análise pronta.',
  }) async {
    if (_preparingAttachment) return;
    setState(() {
      _preparingAttachment = true;
      _assistantState = NovaAssistantState.executing;
      _systemStatus = 'Preparando anexo...';
    });

    try {
      final prepared = await _fileService.prepareAttachment(
        attachment,
        context: _conversationContextLabel(),
      );
      if (!mounted) return;
      setState(() {
        _composerAttachment = prepared;
        _assistantState = NovaAssistantState.suggesting;
        _systemStatus = 'Anexo pronto para análise no chat.';
      });
      _showSnack(successMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assistantState = NovaAssistantState.responding;
        _systemStatus = 'Falha ao preparar anexo.';
      });
      _showSnack(
        _humanizeApiError(
          error,
          fallback: 'Não consegui preparar o arquivo agora.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _preparingAttachment = false;
          if (_assistantState == NovaAssistantState.responding) {
            _assistantState = NovaAssistantState.idle;
          }
        });
      }
    }
  }

  Future<void> _pickComposerAttachment() async {
    final picked = await _fileService.pickAttachment();
    if (picked == null) return;
    await _prepareAttachment(
      picked,
      successMessage: 'Arquivo anexado e interpretado pela NOVA.',
    );
  }

  Future<void> _pickQuickPhoto() async {
    try {
      final picked = await _cameraService.capturePhoto();
      if (picked == null) return;
      await _prepareAttachment(
        picked,
        successMessage: 'Foto capturada e pronta para análise.',
      );
    } catch (_) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) {
        _showSnack('Não consegui abrir a câmera agora.');
        return;
      }
      final file = result.files.first;
      if (file.bytes == null && (file.path ?? '').trim().isEmpty) {
        _showSnack('Não consegui ler a imagem selecionada.');
        return;
      }
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await _prepareAttachment(
        NovaAttachment(
          name: file.name,
          mimeType: 'image/jpeg',
          bytes: bytes,
          localPath: file.path,
        ),
        successMessage: 'Imagem adicionada e pronta para análise.',
      );
    }
  }

  bool _isMusicCommand(String input) {
    final t = input.toLowerCase().trim();
    return t.contains('tocar musica') ||
        t.contains('tocar música') ||
        t.contains('abrir musica') ||
        t.contains('abrir música') ||
        t == '/musica' ||
        t == '/música' ||
        t == '/play';
  }

  bool _isPlaylistFavoritaCommand(String input) {
    final t = _normalizarParaMatch(input);
    return t.contains('playlist favorita') ||
        t.contains('play list favorita') ||
        t.contains('tocar a playlist favorita') ||
        t.contains('toque minha playlist favorita') ||
        t.contains('toque a playlist favorita dela');
  }

  bool _isYoutubeOpenCommand(String input) {
    final t = _normalizarParaMatch(input);
    return t == 'abrir youtube' ||
        t == 'abre youtube' ||
        t == 'open youtube' ||
        t == 'abrir o youtube';
  }

  bool _isMapsOpenCommand(String input) {
    final t = _normalizarParaMatch(input);
    return t == 'abrir maps' ||
        t == 'abre maps' ||
        t == 'open maps' ||
        t == 'abrir o maps' ||
        t == 'abrir mapa' ||
        t == 'abrir mapas' ||
        t == 'abrir google maps' ||
        t == 'abre google maps';
  }

  String? _extractYoutubeSearchQuery(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(
        r'^(?:pesquise|pesquisar|procure|procurar|busque|buscar)\s+(?:no\s+)?youtube\s+(?:por|sobre)?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:abra|abrir|abre|open)\s+(?:o\s+)?youtube\s+(?:e\s+)?(?:pesquise|pesquisar|procure|procurar|busque|buscar)?\s*(?:por|sobre)?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:youtube)\s+(?:pesquise|pesquisar|procure|procurar|busque|buscar)?\s*(?:por|sobre)?\s*(.+)$',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final query = (match.group(1) ?? '').trim();
      if (query.isEmpty) continue;
      return query.trim().replaceAll(RegExp(r'^[,:-]+|[,:-]+$'), '').trim();
    }

    return null;
  }

  String? _extractMapsSearchQuery(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(
        r'^(?:pesquise|pesquisar|procure|procurar|busque|buscar)\s+(?:no\s+)?(?:google\s+)?maps?\s+(?:por|sobre|em)?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:abra|abrir|abre|open)\s+(?:o\s+)?(?:google\s+)?maps?\s+(?:e\s+)?(?:pesquise|pesquisar|procure|procurar|busque|buscar)?\s*(?:por|sobre|em)?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:mapa|mapas|maps|google maps)\s+(?:pesquise|pesquisar|procure|procurar|busque|buscar)?\s*(?:por|sobre|em)?\s*(.+)$',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final query = (match.group(1) ?? '').trim();
      if (query.isEmpty) continue;
      return query.trim().replaceAll(RegExp(r'^[,:-]+|[,:-]+$'), '').trim();
    }

    return null;
  }

  bool _isCurrentLocationCommand(String input) {
    final t = _normalizarParaMatch(input);
    return t == 'qual e minha localizacao' ||
        t == 'qual a minha localizacao' ||
        t == 'minha localizacao' ||
        t == 'onde eu estou' ||
        t == 'onde estou';
  }

  String? _extractWhereIsQuery(String input) {
    final cleaned = input.trim();
    final patterns = <RegExp>[
      RegExp(r'^(?:nova[\s,:-]+)?onde fica\s+(.+)$', caseSensitive: false),
      RegExp(r'^(?:nova[\s,:-]+)?onde está\s+(.+)$', caseSensitive: false),
      RegExp(r'^(?:nova[\s,:-]+)?onde esta\s+(.+)$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final query = (match.group(1) ?? '').trim();
      if (query.isEmpty) continue;
      return query.replaceAll(RegExp(r'^[,:-]+|[,:-]+$'), '').trim();
    }
    return null;
  }

  String? _extractRouteQuery(String input) {
    final cleaned = input.trim();
    final patterns = <RegExp>[
      RegExp(
        r'^(?:nova[\s,:-]+)?como chego (?:em|até|ate|para)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:nova[\s,:-]+)?rota (?:para|até|ate)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:nova[\s,:-]+)?ir (?:para|até|ate)\s+(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final query = (match.group(1) ?? '').trim();
      if (query.isEmpty) continue;
      return query.replaceAll(RegExp(r'^[,:-]+|[,:-]+$'), '').trim();
    }
    return null;
  }

  String? _extractNearbyQuery(String input) {
    final cleaned = _normalizarParaMatch(input);
    final patterns = <RegExp>[
      RegExp(r'^(.+?)\s+(?:perto de mim|proximo de mim|aqui perto)$'),
      RegExp(
        r'^(?:encontre|achar|ache|buscar|busque|procure)\s+(.+?)\s+(?:perto de mim|proximo de mim|aqui perto)$',
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final query = (match.group(1) ?? '').trim();
      if (query.isEmpty) continue;
      return query;
    }
    return null;
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Map<String, dynamic>> _captureCurrentLocation({
    bool syncBackend = true,
  }) async {
    final allowed = await _ensureLocationPermission();
    if (!allowed) return <String, dynamic>{};

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final reverse = await _api.reverseLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final label = (reverse['label']?.toString().trim() ?? '');
    final display = (reverse['display_name']?.toString().trim() ?? '');
    final resolvedLabel = label.isNotEmpty
        ? label
        : (display.isNotEmpty ? display : 'sua posição atual');

    if (syncBackend) {
      await _api.updateLocation(
        label: resolvedLabel,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    return <String, dynamic>{
      'label': resolvedLabel,
      'display_name': display,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'maps_url': reverse['maps_url']?.toString() ?? '',
    };
  }

  Future<String> _falarLocalizacaoAtual() async {
    try {
      final loc = await _captureCurrentLocation();
      if (loc.isEmpty) {
        return 'Não consegui acessar sua localização agora. Ative o GPS e permita o acesso de localização para a NOVA.';
      }
      final label = loc['label']?.toString().trim() ?? '';
      final display = loc['display_name']?.toString().trim() ?? '';
      if (display.isNotEmpty && display != label) {
        return 'Você está perto de $label. Referência completa: $display.';
      }
      return 'Você está perto de $label.';
    } catch (_) {
      return 'Não consegui atualizar sua localização agora.';
    }
  }

  Future<String> _abrirYoutube([String query = '']) async {
    final normalizedQuery = query.trim();
    final uri = normalizedQuery.isEmpty
        ? Uri.parse('https://www.youtube.com')
        : Uri.https('www.youtube.com', '/results', {
            'search_query': normalizedQuery,
          });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      return normalizedQuery.isEmpty
          ? 'Não consegui abrir o YouTube agora.'
          : 'Não consegui abrir a pesquisa no YouTube agora.';
    }
    return normalizedQuery.isEmpty
        ? 'Abrindo o YouTube.'
        : 'Abrindo pesquisa no YouTube por "$normalizedQuery".';
  }

  Future<String> _abrirMaps([String query = '']) async {
    final normalizedQuery = query.trim();
    final uri = normalizedQuery.isEmpty
        ? Uri.parse('https://www.google.com/maps')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(normalizedQuery)}',
          );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      return normalizedQuery.isEmpty
          ? 'Não consegui abrir o Maps agora.'
          : 'Não consegui abrir a busca no Maps agora.';
    }
    return normalizedQuery.isEmpty
        ? 'Abrindo o Maps.'
        : 'Abrindo busca no Maps por "$normalizedQuery".';
  }

  Future<String> _abrirBuscaMapaPorLugar(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return 'Me diga o lugar que você quer localizar.';
    }
    try {
      Map<String, dynamic> loc = <String, dynamic>{};
      try {
        loc = await _captureCurrentLocation(syncBackend: true);
      } catch (_) {
        loc = <String, dynamic>{};
      }

      final payload = await _api.searchMapPlaces(
        normalizedQuery,
        latitude: loc['latitude'] is double ? loc['latitude'] as double : null,
        longitude:
            loc['longitude'] is double ? loc['longitude'] as double : null,
      );
      final items = payload['items'];
      if (items is List && items.isNotEmpty) {
        final first = items.first;
        if (first is Map) {
          final url = first['maps_url']?.toString() ?? '';
          final rawLabel = first['name']?.toString().trim() ?? '';
          final label = rawLabel.isNotEmpty ? rawLabel : normalizedQuery;
          if (url.isNotEmpty) {
            final ok = await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            if (ok) return 'Abrindo o Maps para $label.';
          }
        }
      }
    } catch (_) {
      // Cai para busca direta no Maps.
    }
    return _abrirMaps(normalizedQuery);
  }

  Future<String> _abrirRotaMaps(String destino) async {
    final normalized = destino.trim();
    if (normalized.isEmpty) {
      return 'Me diga para onde você quer ir.';
    }
    String originSuffix = '';
    try {
      final loc = await _captureCurrentLocation(syncBackend: true);
      final lat = loc['latitude'];
      final lon = loc['longitude'];
      if (lat is double && lon is double) {
        originSuffix =
            '&origin=${Uri.encodeComponent('${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}')}';
      }
    } catch (_) {
      originSuffix = '';
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(normalized)}$originSuffix',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) return 'Não consegui abrir a rota no Maps agora.';
    return 'Abrindo rota para "$normalized" no Maps.';
  }

  Future<String> _abrirPlaylistFavoritaYoutube() async {
    const url =
        'https://youtube.com/playlist?list=PLR5Cmjo90BNguiSb2wDShPdKoa-Xiw5x1&si=ZsqnYwcp7fkvUj35';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) {
      return 'Abrindo sua playlist favorita no YouTube, chefe.';
    }
    return 'Não consegui abrir o YouTube agora.';
  }

  Future<String> _adicionarMusicasNaBiblioteca() async {
    if (!PlatformCapabilities.supportsLocalMusicLibrary) {
      return 'Biblioteca local de músicas não está disponível nesta plataforma.';
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return 'Nenhum arquivo de música foi selecionado.';
    }

    final files = <Map<String, String>>[];
    for (final file in result.files) {
      final path = file.path ?? '';
      if (path.isEmpty) continue;
      files.add({'path': path, 'name': file.name});
    }
    if (files.isEmpty) return 'Arquivos inválidos.';

    await _localDb.addMusicFiles(files);
    await _loadMusicLibrary();
    return '${files.length} música(s) adicionada(s) à biblioteca local.';
  }

  Future<String> _tocarMusicaLocal([String query = '']) async {
    if (!PlatformCapabilities.supportsLocalMusicLibrary) {
      return 'A reprodução local de músicas só está disponível fora da Web.';
    }

    if (_musicLibrary.isEmpty) {
      final added = await _adicionarMusicasNaBiblioteca();
      if (_musicLibrary.isEmpty) return added;
    }

    Map<String, String>? selecionada;
    final q = query.toLowerCase().trim();
    if (q.isNotEmpty) {
      for (final item in _musicLibrary) {
        final nome = (item['name'] ?? '').toLowerCase();
        if (nome.contains(q)) {
          selecionada = item;
          break;
        }
      }
    }
    selecionada ??= _musicLibrary.first;

    final path = selecionada['path'] ?? '';
    if (path.isEmpty) return 'Arquivo de música inválido.';

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    return 'Tocando agora: ${selecionada['name']}';
  }

  String _listarMusicas() {
    if (!PlatformCapabilities.supportsLocalMusicLibrary) {
      return 'A biblioteca local de músicas não está disponível nesta plataforma.';
    }
    if (_musicLibrary.isEmpty) return 'Sua biblioteca de músicas está vazia.';
    final itens = _musicLibrary.take(20).toList();
    final linhas = <String>[];
    for (var i = 0; i < itens.length; i++) {
      linhas.add('${i + 1}. ${itens[i]['name']}');
    }
    return 'Biblioteca local:\n${linhas.join('\n')}';
  }

  bool _isAffirmativeReply(String input) {
    final normalized = _normalizarParaMatch(input);
    return normalized == 'sim' ||
        normalized == 's' ||
        normalized == 'ok' ||
        normalized == 'confirmo' ||
        normalized == 'pode' ||
        normalized == 'pode sim';
  }

  bool _isNegativeReply(String input) {
    final normalized = _normalizarParaMatch(input);
    return normalized == 'nao' ||
        normalized == 'n' ||
        normalized == 'cancelar' ||
        normalized == 'cancela' ||
        normalized == 'negativo';
  }

  String _preferredCalendarEmail() {
    final configured = _config['calendar_email']?.toString().trim() ?? '';
    if (configured.isNotEmpty) return configured;
    return '';
  }

  String _preferredCalendarLabel() {
    final configured = _preferredCalendarEmail();
    if (configured.isNotEmpty) return configured;
    return 'agenda padrao do aparelho';
  }

  String _formatCalendarDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year às $hour:$minute';
  }

  Future<String?> _handlePendingLocalCalendarConfirmation(
      String message) async {
    final pending = _pendingLocalCalendarEvent;
    if (pending == null || pending.isEmpty) return null;

    if (_isNegativeReply(message)) {
      if (mounted) {
        setState(() => _pendingLocalCalendarEvent = null);
      } else {
        _pendingLocalCalendarEvent = null;
      }
      return 'Tudo bem. Não agendei nada na agenda do celular.';
    }

    if (!_isAffirmativeReply(message)) {
      return 'Preciso de uma confirmação objetiva para criar esse evento na agenda do celular. Responda sim ou nao.';
    }

    final title = pending['title']?.toString().trim() ?? 'Compromisso';
    final description = pending['description']?.toString().trim() ?? '';
    final startAt = pending['start_at'];
    final endAt = pending['end_at'];
    if (startAt is! DateTime || endAt is! DateTime) {
      if (mounted) {
        setState(() => _pendingLocalCalendarEvent = null);
      } else {
        _pendingLocalCalendarEvent = null;
      }
      return 'Perdi os dados desse agendamento. Me peça novamente que eu preparo de novo.';
    }

    final result = await _deviceCalendar.createEvent(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      preferredEmail: _preferredCalendarEmail(),
    );
    if (mounted) {
      setState(() => _pendingLocalCalendarEvent = null);
    } else {
      _pendingLocalCalendarEvent = null;
    }

    if (result['ok'] == true) {
      final calendarOwner = result['calendar_owner']?.toString().trim() ?? '';
      final calendarName = result['calendar_name']?.toString().trim() ?? '';
      final destino = calendarOwner.isNotEmpty
          ? calendarOwner
          : (calendarName.isNotEmpty
              ? calendarName
              : _preferredCalendarLabel());
      return 'Evento criado no calendario do celular e sincronizado pela agenda $destino: $title em ${_formatCalendarDateTime(startAt)}.';
    }

    final messageOut = result['message']?.toString().trim() ?? '';
    if (messageOut.isNotEmpty) {
      return 'Não consegui criar o evento direto no celular: $messageOut';
    }
    return 'Não consegui criar o evento direto no celular agora.';
  }

  Future<String?> _handleLocalCalendarCommand(String message) async {
    if (!_deviceCalendar.supportsNativeCalendar) return null;
    if (!DeviceCalendarService.looksLikeCalendarRequest(message)) return null;

    final parsed = _deviceCalendar.parseRequest(message);
    if (parsed['ok'] != true) {
      return parsed['message']?.toString().trim().isNotEmpty == true
          ? parsed['message']?.toString()
          : 'Nao consegui entender esse agendamento.';
    }

    final startAt = parsed['start_at'];
    final endAt = parsed['end_at'];
    if (startAt is! DateTime || endAt is! DateTime) {
      return 'Nao consegui montar a data desse evento no celular.';
    }

    final pending = <String, dynamic>{
      'title': parsed['title'],
      'description': parsed['description'],
      'start_at': startAt,
      'end_at': endAt,
      'assumptions': parsed['assumptions'],
    };
    if (mounted) {
      setState(() => _pendingLocalCalendarEvent = pending);
    } else {
      _pendingLocalCalendarEvent = pending;
    }

    final assumptions = parsed['assumptions'] is List
        ? (parsed['assumptions'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final buffer = StringBuffer()
      ..writeln(
        'Posso agendar isso direto na Google Agenda do seu celular (${_preferredCalendarLabel()}). Responda sim ou nao.',
      )
      ..writeln(
        'Evento: ${parsed['title']} em ${_formatCalendarDateTime(startAt)}.',
      );
    if (assumptions.isNotEmpty) {
      buffer.writeln('Observações: ${assumptions.join(' ')}');
    }
    return buffer.toString().trim();
  }

  Future<String?> _handleLocalUiCommands(String message) async {
    final pendingCalendarReply =
        await _handlePendingLocalCalendarConfirmation(message);
    if (pendingCalendarReply != null) {
      return pendingCalendarReply;
    }

    final t = _normalizarParaMatch(message);

    if (t == 'abrir usuarios' || t == 'open usuarios') {
      _openUsersDialog();
      return 'Abrindo usuários.';
    }
    if (t == 'abrir ensinar' || t == 'abrir ensino') {
      _openTeachDialog();
      return 'Abrindo tela de ensino.';
    }
    if (t == 'abrir editar base' || t == 'abrir base de conhecimento') {
      _openKnowledgeDialog();
      return 'Abrindo base de conhecimento.';
    }
    if (t == 'abrir configuracoes' || t == 'abrir config') {
      _openConfigDialog();
      return 'Abrindo configurações.';
    }
    if (t == 'abrir lembretes' || t == 'mostrar lembretes') {
      _openRemindersDialog();
      return 'Abrindo lembretes.';
    }
    if (t == 'abrir documentos' ||
        t == 'analisar documento' ||
        t == '/documentos') {
      _openDocumentAnalysisDialog();
      return 'Abrindo análise de documentos.';
    }
    if (t == 'abrir help' ||
        t == 'abrir ajuda' ||
        t == 'mostrar comandos' ||
        t == '/help') {
      _openHelpDialog();
      return 'Abrindo central de ajuda.';
    }
    if (t == 'abrir compatibilidade' ||
        t == 'mostrar compatibilidade' ||
        t == '/compatibilidade') {
      _openCompatibilityDialog();
      return 'Abrindo compatibilidade do dispositivo.';
    }
    if (t == 'ativar modo escuta' ||
        t == 'ligar modo escuta' ||
        t == 'ativar escuta') {
      setState(() => _config['escuta_ativa'] = true);
      await _saveLocalState();
      await _initSpeech();
      return 'Modo escuta ativado.';
    }
    if (t == 'desativar modo escuta' ||
        t == 'desligar modo escuta' ||
        t == 'desativar escuta') {
      setState(() => _config['escuta_ativa'] = false);
      _manualListeningStop = true;
      await _speech.stop();
      await BackgroundWakeService.stop();
      await _saveLocalState();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return 'Modo escuta desativado.';
    }
    if (t.contains('adicionar musica') || t.contains('adicionar musicas')) {
      return _adicionarMusicasNaBiblioteca();
    }
    if (t.contains('abrir bluetooth') ||
        t.contains('conectar bluetooth') ||
        t.contains('parear bluetooth') ||
        t.contains('conectar dispositivo bluetooth')) {
      final ok = await _deviceConnectivity.openBluetoothSettings();
      return ok
          ? 'Abrindo Bluetooth para conectar seu dispositivo.'
          : 'Este atalho de Bluetooth funciona no Android.';
    }
    if (t.contains('conectar tv') ||
        t.contains('conectar na tv') ||
        t.contains('espelhar tela') ||
        t.contains('transmitir tela') ||
        t.contains('abrir cast')) {
      final ok = await _deviceConnectivity.openCastSettings();
      return ok
          ? 'Abrindo configurações de transmissão de tela para TV/telas.'
          : 'Este atalho de transmissão funciona no Android.';
    }
    if (t.contains('android auto') ||
        t.contains('abrir auto') ||
        t.contains('conectar carro')) {
      final ok = await _deviceConnectivity.openAndroidAuto();
      return ok
          ? 'Abrindo Android Auto.'
          : 'Não consegui abrir Android Auto agora.';
    }
    if (t.contains('abrir termux') ||
        t.contains('modo termux') ||
        t.contains('terminal seguro')) {
      final ok = await _deviceConnectivity.openTermux();
      return ok
          ? 'Abrindo Termux em modo de segurança defensiva.'
          : 'Não consegui abrir o Termux agora.';
    }
    if (_isCurrentLocationCommand(message)) {
      return _falarLocalizacaoAtual();
    }
    final localCalendarReply = await _handleLocalCalendarCommand(message);
    if (localCalendarReply != null) {
      return localCalendarReply;
    }
    final routeQuery = _extractRouteQuery(message);
    if (routeQuery != null) {
      return _abrirRotaMaps(routeQuery);
    }
    final nearbyQuery = _extractNearbyQuery(message);
    if (nearbyQuery != null) {
      return _abrirBuscaMapaPorLugar('$nearbyQuery perto de mim');
    }
    final whereIsQuery = _extractWhereIsQuery(message);
    if (whereIsQuery != null) {
      return _abrirBuscaMapaPorLugar(whereIsQuery);
    }
    final mapsQuery = _extractMapsSearchQuery(message);
    if (mapsQuery != null) {
      return _abrirBuscaMapaPorLugar(mapsQuery);
    }
    if (_isMapsOpenCommand(message)) {
      return _abrirMaps();
    }
    final youtubeQuery = _extractYoutubeSearchQuery(message);
    if (youtubeQuery != null) {
      return _abrirYoutube(youtubeQuery);
    }
    if (_isYoutubeOpenCommand(message)) {
      return _abrirYoutube();
    }
    if (_isPlaylistFavoritaCommand(message)) {
      return _abrirPlaylistFavoritaYoutube();
    }
    if (t == '/varredura' ||
        t == '/scan' ||
        t.contains('varredura do sistema') ||
        t.contains('status detalhado do sistema') ||
        t.contains('status de software e hardware') ||
        t.contains('varredura de software e hardware')) {
      return _gerarVarreduraSoftwareHardware();
    }
    if (t == '/seguranca' ||
        t == '/segurança' ||
        t == '/auditoria' ||
        t.contains('varredura de seguranca') ||
        t.contains('varredura de segurança') ||
        t.contains('auditoria de seguranca') ||
        t.contains('auditoria de segurança')) {
      return _gerarVarreduraSegurancaFormal();
    }
    if (t.contains('listar musicas') || t == '/musicas') {
      return _listarMusicas();
    }
    if (t.contains('parar musica') || t == '/stop') {
      await _audioPlayer.stop();
      return 'Música parada.';
    }
    if (_isMusicCommand(message)) {
      final q = message
          .toLowerCase()
          .replaceAll('tocar música', '')
          .replaceAll('tocar musica', '')
          .replaceAll('/play', '')
          .trim();
      return _tocarMusicaLocal(q);
    }

    return null;
  }

  Future<String> _gerarVarreduraSoftwareHardware() async {
    final hasPin = await _secureSecrets.hasAdminPin();
    final canBio = await _appSecurity.canUseBiometrics();
    return _systemScan.buildDetailedReport(
      api: _api,
      config: _config,
      hasAdminPin: hasPin,
      canUseBiometric: canBio,
    );
  }

  Future<String> _gerarVarreduraSegurancaFormal() async {
    final localReport = await _gerarVarreduraSoftwareHardware();
    try {
      final audit = await _api.getSecurityAudit();
      final score = audit['score']?.toString() ?? '-';
      final nivel = audit['nivel']?.toString() ?? '-';
      final achados =
          (audit['achados'] is List) ? (audit['achados'] as List) : const [];
      final prioridades = (audit['prioridades'] is List)
          ? (audit['prioridades'] as List)
          : const [];

      final linhas = <String>[
        'Checklist formal de segurança:',
        '- Score: $score/100 ($nivel)',
        '- Achados relevantes:',
      ];
      if (achados.isEmpty) {
        linhas.add('  * Nenhum achado crítico retornado pelo backend.');
      } else {
        for (final item in achados.take(6)) {
          if (item is! Map) continue;
          final sev = item['severidade']?.toString() ?? 'info';
          final titulo = item['titulo']?.toString() ?? 'achado';
          final acao = item['acao']?.toString() ?? 'revisar';
          linhas.add('  * [$sev] $titulo -> $acao');
        }
      }
      linhas.add('- Hardening por prioridade:');
      if (prioridades.isEmpty) {
        linhas
            .add('  * Revisar segredos, permissões, autenticação e auditoria.');
      } else {
        for (final p in prioridades.take(6)) {
          linhas.add('  * ${p.toString()}');
        }
      }

      linhas.add('');
      linhas.add(localReport);
      return linhas.join('\n');
    } catch (_) {
      return 'Não consegui consultar a auditoria formal no backend agora.\n\n$localReport';
    }
  }

  Future<String?> _promptAdminPin() async {
    if (!mounted) return null;
    final controller = TextEditingController();
    String? pin;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final colors = context.novaColors;
        return NovaPanelDialog(
          title: 'PIN Administrativo',
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirme seu PIN para liberar recursos administrativos da NOVA.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Digite o PIN',
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    pin = controller.text.trim();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          pin = controller.text.trim();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    return pin;
  }

  Future<bool> _ensureAdminAccess() async {
    if (_config['admin_guard'] == false) return true;

    final now = DateTime.now();
    if (_adminUnlocked &&
        _adminUnlockedAt != null &&
        now.difference(_adminUnlockedAt!) < const Duration(minutes: 10)) {
      return true;
    }

    final canBio = await _appSecurity.canUseBiometrics();
    if (canBio) {
      final ok = await _appSecurity.authenticateAdmin();
      if (ok) {
        _adminUnlocked = true;
        _adminUnlockedAt = DateTime.now();
        return true;
      }
    }

    final hasPin = await _secureSecrets.hasAdminPin();
    if (!hasPin) return false;

    final pin = await _promptAdminPin();
    if (pin == null || pin.isEmpty) return false;

    final ok = await _secureSecrets.validateAdminPin(pin);
    if (!ok) {
      _showSnack('PIN inválido.');
      return false;
    }
    _adminUnlocked = true;
    _adminUnlockedAt = DateTime.now();
    return true;
  }

  Future<void> _openRemindersDialog() async {
    final textController = TextEditingController();
    DateTime? selectedDateTime;

    await _loadReminders();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> addReminder() async {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              if (selectedDateTime == null) {
                _showSnack('Defina data e hora para o lembrete.');
                return;
              }
              final whenIso = selectedDateTime?.toIso8601String() ?? '';
              try {
                Map<String, dynamic>? createdItem;
                bool synced = false;
                try {
                  final created =
                      await _api.addReminder(text: text, when: whenIso);
                  if (created['ok'] == true && created['item'] is Map) {
                    createdItem =
                        Map<String, dynamic>.from(created['item'] as Map);
                    synced = true;
                  }
                } catch (_) {
                  // fallback local logo abaixo
                }

                createdItem ??= {
                  'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                  'texto': text,
                  'quando': whenIso,
                  'criado_em': DateTime.now().toIso8601String(),
                  'feito': false,
                };

                bool localSaved = false;
                try {
                  await _localDb.upsertReminder(createdItem);
                  localSaved = true;
                } catch (_) {
                  localSaved = false;
                }
                if (!synced && !localSaved) {
                  throw Exception('local_reminder_save_failed');
                }
                final notifId = _notificationIdFromReminderId(
                  (createdItem['id'] ?? '').toString(),
                );
                await _notifications.scheduleReminder(
                  id: notifId,
                  title: 'Lembrete da NOVA',
                  body: text,
                  when: selectedDateTime!,
                );
                textController.clear();
                selectedDateTime = null;
                await _loadReminders();
                setLocalState(() {});
                _showSnack(
                  synced
                      ? 'Lembrete salvo e sincronizado com backend.'
                      : 'Lembrete salvo localmente (sem backend no momento).',
                );
              } catch (_) {
                _showSnack('Falha ao salvar lembrete.');
              }
            }

            Future<void> pickDateTime() async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: DateTime.now(),
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time == null) return;
              selectedDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              setLocalState(() {});
            }

            return NovaPanelDialog(
              title: 'LEMBRETES',
              child: SizedBox(
                width: 640,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NovaInput(
                        controller: textController,
                        hintText: 'Ex: lembrar de pagar conta'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDateTime == null
                                ? 'Sem horário definido'
                                : 'Alerta: ${selectedDateTime!.toLocal()}',
                            style: const TextStyle(color: Color(0xFF6FA6C6)),
                          ),
                        ),
                        TextButton(
                          onPressed: pickDateTime,
                          child: const Text('Definir horário'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: addReminder,
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: _reminders.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Nenhum lembrete salvo.',
                                  style: TextStyle(color: Color(0xFF5E86A3)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _reminders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = _reminders[index];
                                final txt = item['texto']?.toString() ?? '-';
                                final when = item['quando']?.toString() ?? '';
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0x52021322),
                                    border: Border.all(
                                        color: const Color(0xFF084D74)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txt,
                                        style: const TextStyle(
                                          color: Color(0xFFD9F5FF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        when.isEmpty ? 'Sem horário' : when,
                                        style: const TextStyle(
                                          color: Color(0xFF6DA7C8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    textController.dispose();
  }

  Future<void> _openCompatibilityDialog() async {
    if (!mounted) return;
    final itens = PlatformCapabilities.matrixRich();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final colors = context.novaColors;
        return NovaPanelDialog(
          title: 'COMPATIBILIDADE',
          child: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispositivo atual: ${PlatformCapabilities.platformName}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...itens.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NovaPanelSection(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label'] ?? '-',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['detail'] ?? '',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          NovaCapabilityBadge(
                              status: item['status'] ?? 'parcial'),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  'Dica: no Android, a NOVA suporta wake word em segundo plano.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDocumentAnalysisDialog() async {
    final allowed = await _ensureAdminAccess();
    if (!mounted) return;
    if (!allowed) {
      _showSnack('Acesso administrativo negado.');
      return;
    }

    String selectedName = '';
    Uint8List? selectedBytes;
    String? selectedPath;
    bool selectedFromCamera = false;
    bool loading = false;
    String error = '';
    String reportText = '';
    String learningText = '';
    String subjectsText = '';

    String formatarRelatorio(Map<String, dynamic> payload) {
      final report = (payload['report'] is Map)
          ? Map<String, dynamic>.from(payload['report'] as Map)
          : <String, dynamic>{};
      final stats = (report['stats'] is Map)
          ? Map<String, dynamic>.from(report['stats'] as Map)
          : <String, dynamic>{};
      final keywords = (report['keywords'] is List)
          ? (report['keywords'] as List)
          : const [];
      final risks =
          (report['risks'] is List) ? (report['risks'] as List) : const [];
      final excerpts = (report['sample_excerpts'] is List)
          ? (report['sample_excerpts'] as List)
          : const [];
      final recs = (report['recommendations'] is List)
          ? (report['recommendations'] as List)
          : const [];
      final image = (report['image'] is Map)
          ? Map<String, dynamic>.from(report['image'] as Map)
          : <String, dynamic>{};
      final detectedLabels = (report['detected_labels'] is List)
          ? (report['detected_labels'] as List)
          : const [];
      final analysisType = report['analysis_type']?.toString() ?? 'document';
      final source = report['source']?.toString() ?? 'arquivo';

      final lines = <String>[
        'Relatório de análise',
        '- Arquivo: ${report['file_name'] ?? '-'}',
        '- Tipo: $analysisType',
        '- Origem: $source',
        '- Gerado em: ${report['generated_at'] ?? '-'}',
        '- Tamanho: ${stats['bytes'] ?? 0} bytes',
        '- Caracteres: ${stats['chars'] ?? 0}',
        '- Palavras: ${stats['words'] ?? 0}',
        '- Páginas estimadas: ${stats['estimated_pages'] ?? 0}',
      ];
      if (image.isNotEmpty) {
        lines.add(
            '- Resolução: ${image['width'] ?? 0}x${image['height'] ?? 0} px');
        lines.add('- Orientação: ${image['orientation'] ?? '-'}');
        lines.add('- Formato: ${image['format'] ?? image['extension'] ?? '-'}');
        if ((image['brightness_label']?.toString() ?? '').isNotEmpty) {
          lines.add('- Iluminação estimada: ${image['brightness_label']}');
        }
      }
      if (detectedLabels.isNotEmpty) {
        final labels = detectedLabels
            .whereType<Map>()
            .map((item) {
              final label = item['label']?.toString().trim() ?? '';
              final confidence = item['confidence']?.toString().trim() ?? '';
              if (label.isEmpty) return '';
              return confidence.isEmpty ? label : '$label ($confidence)';
            })
            .where((item) => item.isNotEmpty)
            .take(6)
            .join(', ');
        if (labels.isNotEmpty) {
          lines.add('- Objetos detectados: $labels');
        }
      }
      lines.addAll([
        '',
        'Resumo executivo:',
        '${report['executive_summary'] ?? 'Sem resumo.'}',
        '',
        'Palavras-chave:',
      ]);
      if (keywords.isEmpty) {
        lines.add('- nenhuma');
      } else {
        for (final k in keywords.take(12)) {
          if (k is! Map) continue;
          lines.add('- ${k['token']}: ${k['count']}');
        }
      }
      lines.add('');
      lines.add('Riscos detectados:');
      if (risks.isEmpty) {
        lines.add('- nenhum risco explícito encontrado');
      } else {
        for (final r in risks.take(8)) {
          lines.add('- ${r.toString()}');
        }
      }
      lines.add('');
      lines.add('Trechos relevantes:');
      if (excerpts.isEmpty) {
        lines.add('- sem trechos');
      } else {
        for (final e in excerpts.take(4)) {
          lines.add('- ${e.toString()}');
        }
      }
      lines.add('');
      lines.add('Recomendações:');
      for (final r in recs.take(6)) {
        lines.add('- ${r.toString()}');
      }
      return lines.join('\n');
    }

    Future<void> analisarSelecionado(StateSetter setLocalState) async {
      if (selectedBytes == null || selectedName.isEmpty) {
        setLocalState(() => error = 'Selecione um arquivo ou imagem antes.');
        return;
      }
      setLocalState(() {
        loading = true;
        error = '';
      });
      try {
        final isImage = _attachmentAnalysis.isImageFileName(selectedName);
        final out = isImage
            ? await _attachmentAnalysis.analyzeImage(
                fileName: selectedName,
                bytes: selectedBytes!,
                filePath: selectedPath,
                fromCamera: selectedFromCamera,
                researchExecutor: ({
                  required String fileName,
                  required String recognizedText,
                  required List<Map<String, dynamic>> labels,
                  required Map<String, dynamic> metadata,
                  required bool fromCamera,
                  required int byteSize,
                }) {
                  return _api.analyzeImageInsights(
                    fileName: fileName,
                    recognizedText: recognizedText,
                    labels: labels,
                    metadata: metadata,
                    fromCamera: fromCamera,
                    byteSize: byteSize,
                  );
                },
              )
            : await _api.analyzeDocument(
                fileName: selectedName,
                bytes: selectedBytes!,
                autoLearn: _config['auto_document_learning'] != false,
              );
        final txt = formatarRelatorio(out);
        final learning = (out['learning'] is Map)
            ? Map<String, dynamic>.from(out['learning'] as Map)
            : <String, dynamic>{};
        final learnOk = learning['ok'] == true;
        final localFallback = learning['local_fallback'] == true;
        final learningMessage = learning['message']?.toString().trim() ?? '';
        final learnMsg = learnOk
            ? 'Aprendizado automático: OK • base atualizada.'
            : localFallback
                ? (learningMessage.isNotEmpty
                    ? learningMessage
                    : 'Relatório gerado localmente no dispositivo.')
                : (learning['skipped'] == true
                    ? 'Aprendizado automático desativado.'
                    : 'Aprendizado automático: sem atualização.');
        setLocalState(() {
          reportText = txt;
          learningText = learnMsg;
          final sm = (learning['subject_memory'] is Map)
              ? Map<String, dynamic>.from(learning['subject_memory'] as Map)
              : <String, dynamic>{};
          final subs =
              (sm['subjects'] is List) ? (sm['subjects'] as List) : const [];
          if (subs.isNotEmpty) {
            subjectsText =
                'Assuntos aprendidos: ${subs.map((e) => e.toString()).join(", ")}';
          } else {
            subjectsText = 'Assuntos aprendidos: nenhum identificado.';
          }
        });
      } catch (e) {
        setLocalState(() {
          error = _humanizeApiError(
            e,
            fallback: 'Falha ao analisar documento.',
          );
        });
      } finally {
        if (context.mounted) setLocalState(() => loading = false);
      }
    }

    Future<void> selecionarArquivo(StateSetter setLocalState) async {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'md',
          'pdf',
          'docx',
          'json',
          'csv',
          'log',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'bmp',
          'gif',
        ],
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      Uint8List? bytes = f.bytes;
      if (bytes == null && (f.path ?? '').isNotEmpty && !kIsWeb) {
        try {
          bytes = await File(f.path!).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes == null || bytes.isEmpty) {
        setLocalState(() => error = 'Não consegui ler o arquivo selecionado.');
        return;
      }
      setLocalState(() {
        selectedName = f.name;
        selectedBytes = bytes;
        selectedPath = f.path;
        selectedFromCamera = false;
        error = '';
        reportText = '';
        learningText = '';
        subjectsText = '';
      });
      await analisarSelecionado(setLocalState);
    }

    Future<void> selecionarImagemGaleria(StateSetter setLocalState) async {
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setLocalState(() {
          selectedName = picked.name;
          selectedBytes = bytes;
          selectedPath = picked.path;
          selectedFromCamera = false;
          error = '';
          reportText = '';
          learningText = '';
          subjectsText = '';
        });
        await analisarSelecionado(setLocalState);
      } catch (e) {
        setLocalState(() {
          error =
              'Não consegui abrir a galeria agora: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }

    Future<void> capturarFotoParaAnalise(StateSetter setLocalState) async {
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 95,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setLocalState(() {
          selectedName = picked.name;
          selectedBytes = bytes;
          selectedPath = picked.path;
          selectedFromCamera = true;
          error = '';
          reportText = '';
          learningText = '';
          subjectsText = '';
        });
        await analisarSelecionado(setLocalState);
      } catch (e) {
        setLocalState(() {
          error =
              'Não consegui capturar a foto agora: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final colors = context.novaColors;
            Future<void> analisar() async => analisarSelecionado(setLocalState);

            Future<void> exportarPdf() async {
              if (reportText.trim().isEmpty) {
                setLocalState(
                    () => error = 'Gere o relatório antes de exportar.');
                return;
              }
              setLocalState(() {
                loading = true;
                error = '';
              });
              try {
                final bytes = await _buildDocumentReportPdf(
                  reportText: reportText,
                  fileName: selectedName,
                );
                final nomeBase = selectedName.trim().isEmpty
                    ? 'relatorio_documento'
                    : selectedName
                        .trim()
                        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
                await Printing.layoutPdf(
                  name: '${nomeBase}_nova.pdf',
                  onLayout: (_) async => bytes,
                );
              } catch (_) {
                setLocalState(() => error = 'Falha ao exportar PDF.');
              } finally {
                if (context.mounted) setLocalState(() => loading = false);
              }
            }

            return NovaPanelDialog(
              title: 'ANÁLISE DE ARQUIVOS',
              child: SizedBox(
                width: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: Text(
                            selectedName.isEmpty
                                ? 'Nenhum arquivo ou imagem selecionado'
                                : 'Arquivo: $selectedName',
                            style: TextStyle(color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => selecionarArquivo(setLocalState),
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: const Text('Arquivo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => selecionarImagemGaleria(setLocalState),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: const Text('Imagem'),
                        ),
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => capturarFotoParaAnalise(setLocalState),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Tirar foto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : analisar,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.analytics_outlined),
                        label: Text(loading
                            ? 'Analisando...'
                            : 'Gerar relatório completo'),
                      ),
                    ),
                    if (learningText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        learningText,
                        style: TextStyle(color: colors.primary),
                      ),
                    ],
                    if (subjectsText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subjectsText,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : exportarPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Exportar relatório em PDF'),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 10),
                    NovaPanelSection(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: SingleChildScrollView(
                          child: Text(
                            reportText.isEmpty
                                ? 'Anexe um documento, escolha uma imagem ou tire uma foto para gerar o relatório.'
                                : reportText,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openHelpDialog() async {
    List<Map<String, dynamic>> topics = [];
    List<Map<String, dynamic>> commands = [];
    String error = '';
    bool loading = false;
    bool isAdvancedItem(String raw) {
      final v = raw.toLowerCase();
      return v.contains('autonomia') ||
          v.contains('observabilidade') ||
          v.contains('rag') ||
          v.contains('agente') ||
          v.contains('auditoria') ||
          v.contains('sess') ||
          v.contains('assunto');
    }

    Future<void> carregar(StateSetter setLocalState) async {
      setLocalState(() {
        loading = true;
        error = '';
      });
      try {
        final out = await _api.getHelpTopics();
        final t = out['topics'];
        final c = out['commands'];
        setLocalState(() {
          topics = (t is List)
              ? t
                  .whereType<Map>()
                  .where((e) =>
                      !isAdvancedItem('${e['topic'] ?? ''} ${e['text'] ?? ''}'))
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];
          commands = (c is List)
              ? c
                  .whereType<Map>()
                  .where((e) =>
                      !isAdvancedItem('${e['cmd'] ?? ''} ${e['desc'] ?? ''}'))
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];
        });
      } catch (_) {
        setLocalState(() {
          error = 'Sem backend agora. Exibindo ajuda local.';
          topics = [
            {
              'topic': 'Identidade',
              'text':
                  'A NOVA é uma assistente de IA com memória, voz, RAG, automações seguras e aprendizado por documentos.',
            },
          ];
          commands = [
            {'cmd': '/help', 'desc': 'Mostra ajuda completa.'},
            {
              'cmd': '/status sistema',
              'desc': 'Status de software e segurança.'
            },
            {'cmd': '/rag <pergunta>', 'desc': 'Consulta base RAG.'},
            {
              'cmd': 'traduza "<texto>" para ...',
              'desc': 'Traduz um texto enviado na própria mensagem.'
            },
            {
              'cmd': 'traduza essa pesquisa para ...',
              'desc': 'Traduz a última pesquisa da conversa.'
            },
            {
              'cmd': 'me fale essa pesquisa em ...',
              'desc':
                  'Atalho por voz/texto para retornar a última pesquisa em outro idioma.'
            },
            {
              'cmd': 'agende ... amanhã às 15:00',
              'desc': 'Cria um evento na Google Agenda com linguagem natural.'
            },
            {
              'cmd': 'marque reunião em 2026-05-01 14:00',
              'desc': 'Agenda compromisso com data e hora definidas.'
            },
            {
              'cmd': 'pesquise no Maps por ...',
              'desc': 'Atalho local por voz/texto para abrir busca no Maps.'
            },
            {
              'cmd': 'pesquise no YouTube por ...',
              'desc': 'Atalho local por voz/texto para abrir busca no YouTube.'
            },
            {'cmd': '/lembrar ...', 'desc': 'Cria lembrete com data/hora.'},
          ];
        });
      } finally {
        setLocalState(() => loading = false);
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final colors = context.novaColors;
            if (topics.isEmpty && commands.isEmpty && !loading) {
              carregar(setLocalState);
            }
            return NovaPanelDialog(
              title: 'HELP • NOVA',
              child: SizedBox(
                width: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Guia completo por tópicos e comandos',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              loading ? null : () => carregar(setLocalState),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(loading ? 'Atualizando...' : 'Atualizar'),
                        ),
                      ],
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    NovaPanelSection(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tópicos',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...topics.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• ${t['topic'] ?? '-'}: ${t['text'] ?? ''}',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    NovaPanelSection(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comandos',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: commands.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final c = commands[index];
                                return Text(
                                  '• ${c['cmd'] ?? '-'}: ${c['desc'] ?? ''}',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeCommand(
    String rawMessage, {
    required bool fromVoice,
    NovaAttachment? attachment,
  }) async {
    final message = rawMessage.trim();
    if (message.isEmpty && attachment == null) return;

    if (fromVoice) {
      _manualListeningStop = true;
      try {
        await _speech.stop();
      } catch (_) {
        // Evita conflito de áudio em aparelhos mais sensíveis.
      }
      if (mounted) {
        setState(() => _isListening = false);
      }
    }

    final outboundText = message.isEmpty && attachment != null
        ? 'Analise o arquivo anexado.'
        : message;
    final chatContext = _attachmentContextForChat(attachment);
    final requestContext = attachment?.fileId?.trim().isNotEmpty == true &&
            attachment?.analysis != null
        ? ''
        : chatContext;

    setState(() {
      final userText = attachment == null
          ? outboundText
          : outboundText.isEmpty
              ? 'Anexo enviado: ${attachment.name}'
              : '$outboundText\n\n[Anexo: ${attachment.name}]';
      _chat.add(NovaChatLine(fromUser: true, text: userText));
      _messageController.clear();
      _sending = true;
      _assistantState = NovaAssistantState.thinking;
      _systemStatus =
          fromVoice ? 'Comando de voz enviado.' : 'Mensagem enviada.';
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final localReply = attachment == null
          ? await _handleLocalUiCommands(outboundText)
          : null;
      if (!mounted) return;
      if (localReply != null) {
        setState(() => _assistantState = NovaAssistantState.executing);
      }

      final payload = localReply != null
          ? _buildLocalStructuredPayload(outboundText, localReply)
          : await _api.sendJarvisMessage(
              outboundText,
              userId: _jarvisUserId(),
              fileId: attachment?.fileId,
              context: requestContext,
            );
      if (!mounted) return;
      final assistantLine = _assistantLineFromPayload(outboundText, payload);
      final speechText = assistantLine.explanation?.trim().isNotEmpty == true
          ? assistantLine.explanation!.trim()
          : assistantLine.text;
      setState(() {
        _chat.add(assistantLine);
        _systemStatus = 'Resposta recebida.';
        _assistantState = assistantLine.suggestions.isNotEmpty
            ? NovaAssistantState.suggesting
            : assistantLine.state;
      });
      await _speak(speechText);
      await _refreshAdminState();
      await _loadReminders();
      await _refreshJarvisFoundation();
    } catch (error) {
      await _refreshBackendConnection();
      if (!mounted) return;
      final message = _humanizeApiError(error);
      setState(() {
        _chat.add(
          NovaChatLine(
            fromUser: false,
            text: message,
            summary: 'Nao consegui concluir agora.',
            explanation: message,
            actions: _actionObjectsFromLabels(
              const [
                'Continuar daqui',
                'Revisar a acao',
                'Organizar próximo passo',
              ],
            ),
            suggestions: _actionObjectsFromLabels(
              const [
                'Comparar fontes',
                'Criar lembrete',
                'Salvar na memoria',
              ],
              firstPrimary: false,
            ),
            state: NovaAssistantState.responding,
          ),
        );
        _systemStatus = 'Erro de conexão em ${_api.baseUrl}.';
        _assistantState = NovaAssistantState.responding;
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          if (_assistantState == NovaAssistantState.responding) {
            _assistantState = NovaAssistantState.idle;
          }
        });
      }
    }
  }

  Future<void> _openTeachDialog() async {
    final allowed = await _ensureAdminAccess();
    if (!mounted) return;
    if (!allowed) {
      _showSnack('Acesso administrativo negado.');
      return;
    }
    final triggerController = TextEditingController();
    final responseController = TextEditingController();
    final categoryController = TextEditingController(text: 'geral');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.novaColors;
        return NovaPanelDialog(
          title: 'ENSINAR NOVA',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ensine a NOVA a responder de um jeito específico.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              const NovaFieldLabel('GATILHO (o que o usuário diz)'),
              const SizedBox(height: 8),
              NovaInput(
                  controller: triggerController,
                  hintText: 'Ex: qual seu nome?'),
              const SizedBox(height: 14),
              const NovaFieldLabel('RESPOSTA DA NOVA'),
              const SizedBox(height: 8),
              NovaInput(
                controller: responseController,
                hintText: 'Ex: Meu nome é NOVA...',
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              const NovaFieldLabel('CATEGORIA'),
              const SizedBox(height: 8),
              NovaInput(controller: categoryController, hintText: 'geral'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final gatilho = triggerController.text.trim();
                    final resposta = responseController.text.trim();
                    final categoria = categoryController.text.trim().isEmpty
                        ? 'geral'
                        : categoryController.text.trim();

                    if (gatilho.isEmpty || resposta.isEmpty) return;

                    try {
                      final items = await _api.createKnowledge(
                        gatilho: gatilho,
                        resposta: resposta,
                        categoria: categoria,
                      );
                      if (!mounted) return;
                      setState(() => _knowledge = items);
                      await _saveLocalState();
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (_) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop(false);
                    }
                  },
                  child: const Text('ENSINAR NOVA'),
                ),
              ),
            ],
          ),
        );
      },
    );

    triggerController.dispose();
    responseController.dispose();
    categoryController.dispose();

    if (saved == true) {
      _showSnack('Novo ensinamento salvo no banco local e backend.');
    } else if (saved == false) {
      _showSnack('Não foi possível salvar ensinamento.');
    }
  }

  Future<void> _openKnowledgeDialog() async {
    final allowed = await _ensureAdminAccess();
    if (!mounted) return;
    if (!allowed) {
      _showSnack('Acesso administrativo negado.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> refreshList() async {
              final items = await _api.getKnowledge();
              if (!mounted) return;
              setState(() => _knowledge = items);
              setLocalState(() {});
              await _saveLocalState();
            }

            Future<void> editItem(Map<String, dynamic> item) async {
              final triggerCtrl = TextEditingController(
                  text: item['gatilho']?.toString() ?? '');
              final responseCtrl = TextEditingController(
                  text: item['resposta']?.toString() ?? '');
              final catCtrl = TextEditingController(
                  text: item['categoria']?.toString() ?? 'geral');

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return NovaPanelDialog(
                    title: 'EDITAR ITEM',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NovaInput(controller: triggerCtrl, hintText: 'Gatilho'),
                        const SizedBox(height: 10),
                        NovaInput(
                            controller: responseCtrl,
                            hintText: 'Resposta',
                            maxLines: 3),
                        const SizedBox(height: 10),
                        NovaInput(controller: catCtrl, hintText: 'Categoria'),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              triggerCtrl.dispose();
              responseCtrl.dispose();
              catCtrl.dispose();

              if (confirmed != true) return;
              final id = item['id']?.toString() ?? '';
              if (id.isEmpty) return;

              try {
                await _api.updateKnowledge(
                  id,
                  gatilho: triggerCtrl.text.trim(),
                  resposta: responseCtrl.text.trim(),
                  categoria: catCtrl.text.trim().isEmpty
                      ? 'geral'
                      : catCtrl.text.trim(),
                );
                await refreshList();
              } catch (_) {
                _showSnack('Falha ao editar item.');
              }
            }

            Future<void> deleteItem(Map<String, dynamic> item) async {
              final id = item['id']?.toString() ?? '';
              if (id.isEmpty) return;
              try {
                final items = await _api.deleteKnowledge(id);
                if (!mounted) return;
                setState(() => _knowledge = items);
                setLocalState(() {});
                await _saveLocalState();
              } catch (_) {
                _showSnack('Falha ao remover item.');
              }
            }

            return NovaPanelDialog(
              title: 'BASE DE CONHECIMENTO',
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _openTeachDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
              ],
              child: SizedBox(
                width: 620,
                child: _knowledge.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            'Nenhum ensinamento ainda.\nUse "Ensinar" para começar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF4D7694)),
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _knowledge.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _knowledge[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x66001423),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFF054E7A)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['gatilho']?.toString() ?? '-',
                                    style: const TextStyle(
                                      color: Color(0xFFBDEBFF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['resposta']?.toString() ?? '-',
                                    style: const TextStyle(
                                        color: Color(0xFF8DB8D4)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        'Categoria: ${item['categoria'] ?? 'geral'}',
                                        style: const TextStyle(
                                          color: Color(0xFF2FD0FF),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => editItem(item),
                                        icon: const Icon(Icons.edit, size: 18),
                                      ),
                                      IconButton(
                                        onPressed: () => deleteItem(item),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openUsersDialog() async {
    final allowed = await _ensureAdminAccess();
    if (!mounted) return;
    if (!allowed) {
      _showSnack('Acesso administrativo negado.');
      return;
    }
    final newUserController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> addUser() async {
              final name = newUserController.text.trim();
              if (name.isEmpty) return;
              try {
                final users = await _api.addUser(name);
                if (!mounted) return;
                setState(() => _users = users);
                newUserController.clear();
                setLocalState(() {});
                await _saveLocalState();
              } catch (_) {
                _showSnack('Falha ao adicionar usuário.');
              }
            }

            Future<void> toggleUser(Map<String, dynamic> user) async {
              final id = user['id']?.toString() ?? '';
              if (id.isEmpty) return;
              final current = user['ativo'] == true;
              try {
                final users = await _api.updateUser(id, active: !current);
                if (!mounted) return;
                setState(() => _users = users);
                setLocalState(() {});
                await _saveLocalState();
              } catch (_) {
                _showSnack('Falha ao atualizar usuário.');
              }
            }

            Future<void> removeUser(Map<String, dynamic> user) async {
              final id = user['id']?.toString() ?? '';
              if (id.isEmpty) return;
              try {
                final users = await _api.deleteUser(id);
                if (!mounted) return;
                setState(() => _users = users);
                setLocalState(() {});
                await _saveLocalState();
              } catch (_) {
                _showSnack('Falha ao remover usuário.');
              }
            }

            return NovaPanelDialog(
              title: 'GERENCIAR USUÁRIOS',
              child: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: NovaInput(
                            controller: newUserController,
                            hintText: 'Nome do novo usuário...',
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: addUser,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Sem usuários cadastrados.',
                          style: TextStyle(color: Color(0xFF6889A2)),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final active = user['ativo'] == true;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0x55001423),
                                border:
                                    Border.all(color: const Color(0xFF05507D)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF00C8FF)
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      (user['nome']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? user['nome']
                                              .toString()
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: Color(0xFF00D1FF)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user['nome']?.toString() ?? '-',
                                          style: const TextStyle(
                                            color: Color(0xFFD7F4FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${user['papel'] ?? 'usuario'} · desde ${user['desde'] ?? '-'}',
                                          style: const TextStyle(
                                              color: Color(0xFF5F8AA8),
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => toggleUser(user),
                                    child: Text(
                                      active ? 'ATIVO' : 'INATIVO',
                                      style: TextStyle(
                                        color: active
                                            ? const Color(0xFF00DCFF)
                                            : const Color(0xFF7A8D9C),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => removeUser(user),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    newUserController.dispose();
  }

  Future<void> _openConfigDialog() async {
    final allowed = await _ensureAdminAccess();
    if (!mounted) return;
    if (!allowed) {
      _showSnack('Acesso administrativo negado.');
      return;
    }
    final wakeWordController = TextEditingController(
      text: _config['wake_word']?.toString() ?? 'nova',
    );
    final telegramTokenController = TextEditingController(
      text: _config['telegram_token']?.toString() ?? '',
    );
    final telegramChatController = TextEditingController(
      text: _config['telegram_chat_id']?.toString() ?? '',
    );
    final apiTokenController = TextEditingController(
      text: _config['api_token']?.toString() ?? '',
    );
    final apiBaseUrlController = TextEditingController(
      text: _config['api_base_url']?.toString() ?? '',
    );
    final calendarEmailController = TextEditingController(
      text: _config['calendar_email']?.toString() ?? '',
    );
    bool vozAtiva = _config['voz_ativa'] == true;
    bool vozNeuralHybrid = _config['voice_neural_hybrid'] != false;
    String voiceProfile =
        _config['voice_profile']?.toString().trim().toLowerCase() ?? 'feminina';
    bool escutaAtiva = _config['escuta_ativa'] != false;
    bool telegramAtivo = _config['telegram_ativo'] == true;
    bool wakeContinuo = _config['continuous_wake'] != false;
    bool pushToTalkOnly = _config['push_to_talk_only'] != false;
    bool autoDocumentLearning = _config['auto_document_learning'] != false;
    bool adminGuard = _config['admin_guard'] != false;
    bool allowVoiceOnLock = _config['allow_voice_on_lock'] != false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final colors = context.novaColors;
            final mutedStyle = TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.35,
            );
            Future<void> salvarConfig() async {
              final rawApiBaseUrl = apiBaseUrlController.text.trim();
              final normalizedApiBaseUrl =
                  ApiEndpointConfig.normalizeBaseUrl(rawApiBaseUrl);
              if (rawApiBaseUrl.isNotEmpty && normalizedApiBaseUrl.isEmpty) {
                _showSnack(
                  'URL da API invalida. Use algo como ${ApiEndpointConfig.exampleManualBaseUrl()}',
                );
                return;
              }

              final wakeContinuoEfetivo = pushToTalkOnly ? false : wakeContinuo;
              final apiToken = apiTokenController.text.trim();
              final novoBackend = {
                'voz_ativa': vozAtiva,
                'voice_neural_hybrid': vozNeuralHybrid,
                'voice_profile': voiceProfile,
                'escuta_ativa': escutaAtiva,
                'wake_word': wakeWordController.text.trim().isEmpty
                    ? 'nova'
                    : wakeWordController.text.trim(),
                'continuous_wake': wakeContinuoEfetivo,
                'push_to_talk_only': pushToTalkOnly,
                'telegram_ativo': telegramAtivo,
                'telegram_token': telegramTokenController.text.trim(),
                'telegram_chat_id': telegramChatController.text.trim(),
                'auto_document_learning': autoDocumentLearning,
                'admin_guard': adminGuard,
                'allow_voice_on_lock': allowVoiceOnLock,
              };
              final novoLocal = {
                ...novoBackend,
                'api_token': apiToken,
                'api_base_url': normalizedApiBaseUrl,
                'calendar_email': calendarEmailController.text.trim(),
              };
              final resolvedApiBaseUrl = ApiEndpointConfig.resolve(
                explicitBaseUrl: normalizedApiBaseUrl,
              ).baseUrl;
              _api.updateConnection(
                baseUrl: normalizedApiBaseUrl,
                apiToken: apiToken,
              );

              try {
                final atualizado = await _api.updateConfig(novoBackend);
                if (!mounted) return;
                setState(() {
                  _config = {..._config, ...atualizado, ...novoLocal};
                  _continuousWakeMode = _config['continuous_wake'] != false;
                  if (_pushToTalkOnly) {
                    _continuousWakeMode = false;
                  }
                  _systemStatus = 'API pronta em $resolvedApiBaseUrl.';
                });
                _syncApiConnectionSettingsFromConfig();
                if (!escutaAtiva) {
                  _manualListeningStop = true;
                  await _speech.stop();
                  await BackgroundWakeService.stop();
                  if (mounted) {
                    setState(() => _isListening = false);
                  }
                } else if (!_effectiveContinuousWake && _isListening) {
                  _manualListeningStop = true;
                  await _speech.stop();
                }
                if (escutaAtiva && _effectiveContinuousWake && !_isListening) {
                  _manualListeningStop = false;
                  await _startListening();
                }
                await _saveLocalState();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _showSnack('Configurações salvas com sucesso.');
              } catch (_) {
                if (!mounted) return;
                setState(() {
                  _config = {..._config, ...novoLocal};
                  _continuousWakeMode = _config['continuous_wake'] != false;
                  if (_pushToTalkOnly) {
                    _continuousWakeMode = false;
                  }
                  _systemStatus =
                      'Config local salva para $resolvedApiBaseUrl.';
                });
                _syncApiConnectionSettingsFromConfig();
                await _saveLocalState();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _showSnack(
                  'Configurações salvas localmente (sem backend no momento).',
                );
              }
            }

            Future<void> definirPinAdmin() async {
              final pin1 = TextEditingController();
              final pin2 = TextEditingController();
              await showDialog<void>(
                context: context,
                builder: (context) {
                  final colors = context.novaColors;
                  return NovaPanelDialog(
                    title: 'Definir PIN administrativo',
                    child: SizedBox(
                      width: 460,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crie um PIN de 4 a 8 dígitos para reforçar o acesso às áreas sensíveis.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: pin1,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              hintText: 'Novo PIN (4-8 dígitos)',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: pin2,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              hintText: 'Confirmar PIN',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () async {
                                    final a = pin1.text.trim();
                                    final b = pin2.text.trim();
                                    if (a.length < 4 || a.length > 8) {
                                      _showSnack(
                                          'PIN deve ter entre 4 e 8 dígitos.');
                                      return;
                                    }
                                    if (a != b) {
                                      _showSnack('PINs não conferem.');
                                      return;
                                    }
                                    await _secureSecrets.setAdminPin(a);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                    _showSnack(
                                        'PIN administrativo atualizado.');
                                  },
                                  child: const Text('Salvar PIN'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              pin1.dispose();
              pin2.dispose();
            }

            return NovaPanelDialog(
              title: 'CONFIGURAÇÕES',
              child: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Voz da NOVA',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  'Respostas em áudio',
                                  style: mutedStyle,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: vozAtiva,
                            onChanged: (value) {
                              vozAtiva = value;
                              setLocalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Aprendizado por documentos',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  'Quando um arquivo é analisado, a NOVA aprende automaticamente e atualiza a base.',
                                  style: mutedStyle,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: autoDocumentLearning,
                            onChanged: (value) {
                              autoDocumentLearning = value;
                              setLocalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Conexao com API',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          NovaInput(
                            controller: apiBaseUrlController,
                            hintText: ApiEndpointConfig.exampleManualBaseUrl(),
                          ),
                          const SizedBox(height: 8),
                          NovaInput(
                            controller: apiTokenController,
                            hintText: 'Token da API (X-API-Key/Bearer)',
                            obscureText: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Opcional. Deixe vazio para usar o auto-detect da plataforma. '
                            'Preencha para apontar o app para um backend especifico sem recompilar. '
                            'Se o backend exigir autenticacao, informe aqui o token da API.',
                            style: mutedStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Agenda do celular',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          NovaInput(
                            controller: calendarEmailController,
                            hintText: 'voce@empresa.com',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Conta preferida para salvar eventos no Android. A NOVA tenta usar essa agenda primeiro.',
                            style: mutedStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Voz Neural Híbrida',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Usa voz neural online e cai para voz local se estiver offline',
                                      style: mutedStyle,
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: vozNeuralHybrid,
                                onChanged: (value) {
                                  vozNeuralHybrid = value;
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: ['feminina', 'francisca', 'thalita']
                                    .contains(voiceProfile)
                                ? voiceProfile
                                : 'feminina',
                            decoration: const InputDecoration(
                              labelText: 'Perfil de voz',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'feminina',
                                child: Text('Feminina (recomendado)'),
                              ),
                              DropdownMenuItem(
                                value: 'francisca',
                                child: Text('Francisca'),
                              ),
                              DropdownMenuItem(
                                value: 'thalita',
                                child: Text('Thalita'),
                              ),
                            ],
                            onChanged: (value) {
                              voiceProfile = (value ?? 'feminina').trim();
                              setLocalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Modo Escuta',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  'Liga/desliga captação do microfone da assistente',
                                  style: mutedStyle,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: escutaAtiva,
                            onChanged: (value) {
                              escutaAtiva = value;
                              if (!escutaAtiva) {
                                wakeContinuo = false;
                              }
                              setLocalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Segurança Administrativa',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Switch.adaptive(
                                value: adminGuard,
                                onChanged: (value) {
                                  adminGuard = value;
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bloqueia telas administrativas com biometria/PIN e guarda segredos em cofre seguro.',
                            style: mutedStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Permitir comando de voz com tela bloqueada',
                                  style: mutedStyle,
                                ),
                              ),
                              Switch.adaptive(
                                value: allowVoiceOnLock,
                                onChanged: (value) {
                                  allowVoiceOnLock = value;
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: definirPinAdmin,
                              child: const Text('Definir/alterar PIN admin'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wake Word',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          NovaInput(
                              controller: wakeWordController, hintText: 'nova'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Modo manual (push-to-talk)',
                                  style: mutedStyle,
                                ),
                              ),
                              Switch.adaptive(
                                value: pushToTalkOnly,
                                onChanged: (value) {
                                  pushToTalkOnly = value;
                                  if (pushToTalkOnly) {
                                    wakeContinuo = false;
                                  }
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Monitor de voz contínuo',
                                  style: mutedStyle,
                                ),
                              ),
                              Switch.adaptive(
                                value: escutaAtiva && !pushToTalkOnly
                                    ? wakeContinuo
                                    : false,
                                onChanged: (value) {
                                  if (!escutaAtiva || pushToTalkOnly) return;
                                  wakeContinuo = value;
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDeco,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Telegram',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Switch.adaptive(
                                value: telegramAtivo,
                                onChanged: (value) {
                                  telegramAtivo = value;
                                  setLocalState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          NovaInput(
                              controller: telegramTokenController,
                              hintText: 'Bot Token'),
                          const SizedBox(height: 8),
                          NovaInput(
                              controller: telegramChatController,
                              hintText: 'Chat ID'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _chat.clear();
                            _systemStatus = 'Histórico limpo.';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                            color:
                                Theme.of(context).colorScheme.error.withValues(
                                      alpha: 0.36,
                                    ),
                          ),
                        ),
                        child: const Text('Limpar histórico de chat'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: salvarConfig,
                        child: const Text('Salvar configurações'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    wakeWordController.dispose();
    telegramTokenController.dispose();
    telegramChatController.dispose();
    apiTokenController.dispose();
    apiBaseUrlController.dispose();
    calendarEmailController.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final colors = context.novaColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(
          colors.brandSurface,
          colors.surfaceStrong,
          context.isNovaDark ? 0.18 : 0.10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colors.glassBorder.withValues(
              alpha: context.isNovaDark ? 0.28 : 0.70,
            ),
          ),
        ),
        elevation: 0,
      ),
    );
  }

  String _humanizeApiError(
    Object error, {
    String fallback = 'Falha ao comunicar com a API.',
  }) {
    var raw = error.toString().trim();
    raw = raw.replaceFirst('Exception: ', '');
    raw = raw.replaceFirst('ApiHttpException: ', '');
    if (raw.isEmpty) return fallback;
    if (raw.contains('Endpoint não encontrado nesse backend') ||
        raw.contains('não possui a rota de autonomia')) {
      return '$raw\n\nDica: atualize/deploy o backend mais recente e '
          'recompile o app com NOVA_API_URL correto.';
    }
    if (raw.contains('Falha de conexão com a API')) {
      return 'Sem conexão com a API em ${_api.baseUrl}. '
          'Verifique URL do backend, internet e porta.';
    }
    return raw;
  }

  Future<bool> _openCreateBrainNoteDialog() async {
    if (!mounted) return false;
    final titleController = TextEditingController();
    final folderController = TextEditingController();
    final contentController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.novaColors;
        return NovaPanelDialog(
          title: 'Nova nota no vault',
          child: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicione uma nota em Markdown para enriquecer o contexto e as conexões do vault.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                NovaInput(
                  controller: titleController,
                  hintText: 'Titulo da nota',
                ),
                const SizedBox(height: 10),
                NovaInput(
                  controller: folderController,
                  hintText: 'Pasta opcional, ex: projetos/atlas',
                ),
                const SizedBox(height: 10),
                NovaPanelSection(
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: contentController,
                    minLines: 8,
                    maxLines: 14,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Escreva em Markdown. Exemplo: [[Projeto Atlas]] #ideia',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          final folder = folderController.text.trim();
                          if (title.isEmpty) {
                            _showSnack('Digite um titulo para a nota.');
                            return;
                          }
                          try {
                            await _api.saveBrainNote(
                              title: title,
                              content: content,
                              folder: folder,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            _showSnack(_humanizeApiError(error));
                          }
                        },
                        child: const Text('Salvar nota'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    titleController.dispose();
    folderController.dispose();
    contentController.dispose();

    if (created == true) {
      _showSnack('Nota salva no vault.');
      return true;
    }
    return false;
  }

  Future<void> _openBrainDialog() async {
    if (!mounted) return;
    var notes = List<Map<String, dynamic>>.from(_brainNotes);
    var graph = Map<String, dynamic>.from(_brainGraph);
    var suggestions = List<Map<String, dynamic>>.from(_brainSuggestions);
    Map<String, dynamic>? selectedNote;
    var backlinks = <String>[];
    var selectedSuggestions = <Map<String, dynamic>>[];
    var loadingNote = false;
    var bootstrapped = false;
    var sheetAlive = true;

    List<String> extractBacklinks(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    Future<void> loadNote(StateSetter setModalState, String noteRef) async {
      final normalized = noteRef.trim();
      if (normalized.isEmpty) return;
      setModalState(() {
        loadingNote = true;
      });
      try {
        final note = await _api.getBrainNote(normalized);
        final backlinkPayload = await _api.getBrainBacklinks(normalized);
        final noteSuggestions =
            await _api.getBrainSuggestions(noteRef: normalized, limit: 8);
        if (!mounted || !sheetAlive) return;
        setModalState(() {
          selectedNote = note;
          backlinks = extractBacklinks(backlinkPayload['backlinks']);
          selectedSuggestions = noteSuggestions;
          loadingNote = false;
        });
      } catch (error) {
        if (!mounted || !sheetAlive) return;
        setModalState(() {
          loadingNote = false;
        });
        _showSnack(_humanizeApiError(error));
      }
    }

    Future<void> refreshVault(StateSetter setModalState) async {
      try {
        final latestNotes = await _api.getBrainNotes(limit: 8);
        final latestSuggestions = await _api.getBrainSuggestions(limit: 8);
        final latestGraph = await _api.getBrainGraph();
        if (!mounted || !sheetAlive) return;
        setState(() {
          _brainNotes = latestNotes;
          _brainSuggestions = latestSuggestions;
          _brainGraph = latestGraph;
        });
        setModalState(() {
          notes = latestNotes;
          suggestions = latestSuggestions;
          graph = latestGraph;
        });
        final ref = selectedNote?['title']?.toString().trim() ??
            (latestNotes.isNotEmpty
                ? latestNotes.first['title']?.toString().trim() ?? ''
                : '');
        if (ref.isNotEmpty) {
          await loadNote(setModalState, ref);
        }
      } catch (error) {
        if (!mounted || !sheetAlive) return;
        _showSnack(_humanizeApiError(error));
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF03111B),
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!bootstrapped) {
              bootstrapped = true;
              if (notes.isNotEmpty) {
                final initialRef =
                    notes.first['title']?.toString().trim() ?? '';
                if (initialRef.isNotEmpty) {
                  Future.microtask(() => loadNote(setModalState, initialRef));
                }
              }
            }

            final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: NovaBrainBoard(
                    notes: notes,
                    graph: graph,
                    suggestions: suggestions,
                    selectedNote: selectedNote,
                    backlinks: backlinks,
                    selectedSuggestions: selectedSuggestions,
                    loadingNote: loadingNote,
                    onRefresh: () => refreshVault(setModalState),
                    onCreateNote: () async {
                      final created = await _openCreateBrainNoteDialog();
                      if (created && sheetAlive) {
                        await refreshVault(setModalState);
                      }
                    },
                    onSelectNote: (noteRef) => loadNote(setModalState, noteRef),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    sheetAlive = false;
  }

  BoxDecoration get _boxDeco {
    final colors = context.novaColors;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.32),
          colors.surface.withValues(alpha: context.isNovaDark ? 0.12 : 0.42),
        ],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: colors.glassBorder.withValues(
          alpha: context.isNovaDark ? 0.38 : 0.88,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color:
              colors.shadow.withValues(alpha: context.isNovaDark ? 0.22 : 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: colors.glassHighlight.withValues(
            alpha: context.isNovaDark ? 0.04 : 0.22,
          ),
          blurRadius: 6,
          offset: const Offset(-2, -2),
        ),
      ],
    );
  }

  Future<void> _openQuickMenu() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'menu-rapido',
      barrierColor: Colors.black.withValues(
        alpha: context.isNovaDark ? 0.26 : 0.12,
      ),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final actions = <({
          String label,
          String description,
          IconData icon,
          VoidCallback onTap
        })>[
          (
            label: 'Cerebro',
            description: 'Vault, conexões, notas e contexto ativo.',
            icon: Icons.hub_outlined,
            onTap: () {
              _openBrainDialog();
            }
          ),
          (
            label: 'Ensinar',
            description: 'Cadastre respostas e comportamentos da NOVA.',
            icon: Icons.school_outlined,
            onTap: _openTeachDialog
          ),
          (
            label: 'Editar Base',
            description: 'Gerencie a base de conhecimento e respostas.',
            icon: Icons.edit_note,
            onTap: _openKnowledgeDialog
          ),
          (
            label: 'Lembretes',
            description: 'Agendamentos, tarefas e lembretes inteligentes.',
            icon: Icons.alarm,
            onTap: _openRemindersDialog
          ),
          (
            label: 'Documentos',
            description: 'Analise arquivos, OCR e aprendizados automáticos.',
            icon: Icons.description_outlined,
            onTap: _openDocumentAnalysisDialog
          ),
          (
            label: 'Help',
            description: 'Ajuda rápida, comandos e guia de uso.',
            icon: Icons.help_outline,
            onTap: _openHelpDialog
          ),
          (
            label: 'Compatibilidade',
            description: 'Verifique capacidades do dispositivo e plataforma.',
            icon: Icons.devices,
            onTap: _openCompatibilityDialog
          ),
          (
            label: 'Configurações',
            description: 'Ajuste voz, API, segurança e comportamento.',
            icon: Icons.settings_outlined,
            onTap: _openConfigDialog
          ),
        ];

        return LayoutBuilder(
          builder: (dialogContext, constraints) {
            final spacing = constraints.maxWidth < 560 ? 12.0 : 14.0;
            final columns = constraints.maxWidth >= 1160
                ? 4
                : (constraints.maxWidth >= 820
                    ? 3
                    : (constraints.maxWidth >= 500 ? 2 : 1));
            final availableWidth = constraints.maxWidth < 460
                ? constraints.maxWidth * 0.94
                : (constraints.maxWidth < 760
                    ? constraints.maxWidth * 0.90
                    : (constraints.maxWidth < 1180
                        ? constraints.maxWidth * 0.84
                        : 980.0));
            final tileWidth = columns == 1
                ? availableWidth - 48
                : (availableWidth - 48 - (spacing * (columns - 1))) / columns;

            return NovaFloatingMenuShell(
              title: 'Menu rápido',
              subtitle:
                  'Acesso flutuante para os módulos principais da NOVA, com layout adaptável para mobile, tablet e desktop.',
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: actions
                    .map(
                      (item) => SizedBox(
                        width: tileWidth,
                        child: NovaFloatingMenuActionCard(
                          label: item.label,
                          description: item.description,
                          icon: item.icon,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            item.onTap();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _handleConversationAction(
    NovaConversationAction action,
  ) async {
    if (_sending) return;
    final label = action.label.trim();
    final normalized = label.toLowerCase();
    final lastAssistant = _lastAssistantLine();
    final context = lastAssistant?.explanation?.trim().isNotEmpty == true
        ? lastAssistant!.explanation!.trim()
        : lastAssistant?.text.trim() ?? '';

    Future<Map<String, dynamic>>? request;
    var openBrainAfter = false;

    if (normalized.contains('continuar projeto')) {
      request = _api.continueProjectAction(
        userId: _jarvisUserId(),
        context: context,
      );
    } else if (normalized.contains('gerar codigo')) {
      await _openDevGeneratorFlow(
        initialPrompt: context.isNotEmpty ? _devPromptSeed() : '',
      );
      return;
    } else if (normalized.contains('melhorar interface')) {
      request = _api.improveInterfaceAction(
        userId: _jarvisUserId(),
        context: context,
      );
    } else if (normalized.contains('organizar proximo passo')) {
      await _executeCommand(
        'Nova, organize o próximo passo com checklist objetivo, prioridade e ordem de execução.',
        fromVoice: false,
      );
      return;
    } else if (normalized.contains('continuar daqui')) {
      request = _api.continueFromHereAction(
        userId: _jarvisUserId(),
        lastAnswer: context,
        context: context,
      );
    } else if (normalized.contains('memoria') || normalized.contains('notas')) {
      request = _api.openMemoryAction(userId: _jarvisUserId());
      openBrainAfter = true;
    }

    if (request == null) {
      final prompt =
          action.prompt.trim().isNotEmpty ? action.prompt.trim() : label;
      await _executeCommand(prompt, fromVoice: false);
      return;
    }

    setState(() {
      _chat.add(NovaChatLine(fromUser: true, text: label));
      _sending = true;
      _assistantState = NovaAssistantState.thinking;
      _systemStatus = 'Executando ação rápida...';
    });

    try {
      final payload = await request;
      if (!mounted) return;
      final assistantLine = _assistantLineFromPayload(label, payload);
      setState(() {
        _chat.add(assistantLine);
        _assistantState = NovaAssistantState.suggesting;
        _systemStatus = 'Ação rápida concluída.';
      });
      if (openBrainAfter) {
        await _openBrainDialog();
      }
    } catch (error) {
      if (!mounted) return;
      final message = _humanizeApiError(
        error,
        fallback: 'Não consegui concluir essa ação agora.',
      );
      setState(() {
        _chat.add(
          NovaChatLine(
            fromUser: false,
            text: message,
            summary: 'Ação rápida indisponível no momento.',
            explanation: message,
            actions: _defaultConversationActions(),
            state: NovaAssistantState.responding,
          ),
        );
        _assistantState = NovaAssistantState.responding;
        _systemStatus = 'Falha ao executar ação rápida.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          if (_assistantState == NovaAssistantState.responding) {
            _assistantState = NovaAssistantState.idle;
          }
        });
      }
    }
  }

  Future<void> _handleModuleTap(NovaModuleSnapshot module) async {
    final normalized = module.title.toLowerCase();
    if (normalized.contains('cerebro')) {
      await _openBrainDialog();
      return;
    }
    if (normalized.contains('dev')) {
      await _openDevGeneratorFlow(initialPrompt: _devPromptSeed());
      return;
    }
    if (normalized.contains('pesquisa')) {
      await _executeCommand(
        'Nova, pesquise na web e compare as melhores referências para o contexto atual.',
        fromVoice: false,
      );
      return;
    }
    if (normalized.contains('finance')) {
      await _executeCommand(
        'Nova, analise custos, viabilidade e plano mensal do contexto atual.',
        fromVoice: false,
      );
      return;
    }
    if (normalized.contains('autom')) {
      await _executeCommand(
        'Nova, organize o fluxo atual, crie um checklist e sugira a próxima automação.',
        fromVoice: false,
      );
    }
  }

  List<NovaConversationAction> _actionsForLine(NovaChatLine line) {
    final merged = <NovaConversationAction>[
      ...line.actions,
      ...line.suggestions.where(
        (item) => !line.actions
            .map((existing) => existing.label.toLowerCase())
            .contains(item.label.toLowerCase()),
      ),
    ];
    return merged.take(4).toList();
  }

  Widget _buildChatThread({
    required bool compact,
    required bool wideChat,
    bool smallMobile = false,
    bool ultrawide = false,
  }) {
    final visibleLines = _visibleChatLines();
    final colors = context.novaColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final chatCompressed = constraints.maxHeight < 360;
        final showShellLabel = !chatCompressed;

        return GlassContainer(
          borderRadius: smallMobile ? 30 : (ultrawide ? 36 : 34),
          padding: EdgeInsets.fromLTRB(
            ultrawide ? 18 : (smallMobile ? 10 : 14),
            ultrawide ? 18 : (smallMobile ? 10 : 14),
            ultrawide ? 18 : (smallMobile ? 10 : 14),
            ultrawide ? 14 : (smallMobile ? 10 : 12),
          ),
          blur: ultrawide ? 26 : 24,
          opacity: context.isNovaDark ? 0.14 : 0.26,
          child: Column(
            children: [
              _buildPinnedConversationCard(
                compact: compact || smallMobile || chatCompressed,
                compressed: chatCompressed,
                microCompact: smallMobile,
                ultrawide: ultrawide,
              ),
              if (showShellLabel) ...[
                SizedBox(height: smallMobile ? 10 : 12),
                Row(
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chat ativo',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: smallMobile ? 12.0 : 12.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      visibleLines.isEmpty
                          ? 'Aguardando'
                          : '${visibleLines.length} registro${visibleLines.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.86),
                        fontSize: smallMobile ? 11.4 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: smallMobile ? 10 : 12),
                Container(
                  height: 1,
                  color: colors.glassBorder.withValues(
                    alpha: context.isNovaDark ? 0.34 : 0.72,
                  ),
                ),
                SizedBox(height: smallMobile ? 10 : 12),
              ] else
                const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    ultrawide ? 6 : (smallMobile ? 0 : 2),
                    0,
                    ultrawide ? 6 : (smallMobile ? 0 : 2),
                    2,
                  ),
                  itemCount: visibleLines.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_sending && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: NovaMessageBubble(
                          fromUser: false,
                          text: _assistantState == NovaAssistantState.executing
                              ? 'Estou executando o próximo passo e organizando a resposta.'
                              : 'Estou entendendo o contexto antes de responder.',
                          timestamp: DateTime.now(),
                          isLive: true,
                        ),
                      );
                    }

                    final adjustedIndex = _sending ? index - 1 : index;
                    final line =
                        visibleLines[visibleLines.length - 1 - adjustedIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: NovaMessageBubble(
                        fromUser: line.fromUser,
                        text: line.text,
                        summary: line.summary,
                        timestamp: line.timestamp,
                        viewLabel: 'Ver codigo',
                        onViewTap: line.copyText?.trim().isNotEmpty == true
                            ? () => _previewGeneratedCode(line)
                            : null,
                        copyLabel: line.copyLabel,
                        onCopyTap: line.copyText?.trim().isNotEmpty == true
                            ? () => _copyGeneratedCode(line)
                            : null,
                        actions:
                            line.fromUser ? const [] : _actionsForLine(line),
                        onActionTap:
                            line.fromUser ? null : _handleConversationAction,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinnedConversationCard({
    required bool compact,
    required bool compressed,
    required bool microCompact,
    required bool ultrawide,
  }) {
    final colors = context.novaColors;
    final line = _pinnedConversationLine();
    final actions = _actionsForLine(line);
    final headline = line.summary?.trim().isNotEmpty == true
        ? line.summary!.trim()
        : _contextualGreetingHeadline();
    final briefingSource = line.explanation?.trim().isNotEmpty == true
        ? line.explanation!.trim()
        : _contextualGreetingBriefing();
    final briefing = _truncateRailText(
      briefingSource,
      limit: microCompact ? 96 : (compact ? 118 : 148),
    );
    final showBriefing = !compressed;
    final showActions = actions.isNotEmpty && !compressed;
    final logoSize =
        microCompact ? 34.0 : (compact ? 38.0 : (ultrawide ? 44.0 : 40.0));
    final titleFontSize =
        microCompact ? 13.2 : (compact ? 14.0 : (ultrawide ? 15.8 : 14.8));
    final briefingFontSize = microCompact ? 12.0 : (compact ? 12.4 : 13.0);
    final actionLimit = microCompact ? 2 : 3;

    final stateColor = switch (_assistantState) {
      NovaAssistantState.idle => colors.textSecondary,
      NovaAssistantState.thinking => const Color(0xFFB7791F),
      NovaAssistantState.responding => colors.primary,
      NovaAssistantState.suggesting => const Color(0xFF18805A),
      NovaAssistantState.executing => const Color(0xFF0F766E),
    };

    Widget statePill() {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: microCompact ? 9 : 10,
          vertical: microCompact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: stateColor.withValues(
            alpha: context.isNovaDark ? 0.18 : 0.12,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: stateColor.withValues(alpha: 0.34),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: stateColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _assistantState.label,
              style: TextStyle(
                color: stateColor,
                fontSize: microCompact ? 11.0 : 11.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget actionChip(
      NovaConversationAction action, {
      bool expand = false,
    }) {
      final chip = GestureDetector(
        onTap: () => _handleConversationAction(action),
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 13,
            vertical: microCompact ? 9 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: context.isNovaDark ? 0.05 : 0.46,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.glassBorder.withValues(
                alpha: context.isNovaDark ? 0.34 : 0.9,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                action.icon ?? Icons.arrow_forward_rounded,
                size: 15,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: microCompact ? 11.8 : 12.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (!expand) {
        return chip;
      }
      return SizedBox(width: double.infinity, child: chip);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        ultrawide ? 18 : (microCompact ? 12 : 15),
        ultrawide ? 16 : (microCompact ? 12 : 14),
        ultrawide ? 18 : (microCompact ? 12 : 15),
        ultrawide ? 16 : (microCompact ? 12 : 14),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              colors.surfaceStrong,
              colors.brandSurface,
              context.isNovaDark ? 0.42 : 0.22,
            )!
                .withValues(alpha: context.isNovaDark ? 0.92 : 0.86),
            Color.lerp(
              colors.surface,
              colors.primarySoft,
              context.isNovaDark ? 0.18 : 0.34,
            )!
                .withValues(alpha: context.isNovaDark ? 0.84 : 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(microCompact ? 22 : 24),
        border: Border.all(
          color: colors.glassBorder.withValues(
            alpha: context.isNovaDark ? 0.36 : 0.94,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: context.isNovaDark ? 0.06 : 0.34,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colors.glassBorder.withValues(
                  alpha: context.isNovaDark ? 0.22 : 0.84,
                ),
              ),
            ),
            child: Text(
              microCompact ? 'Agora' : 'Sessão ativa',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: microCompact ? 10 : 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NovaMetalLogo(size: logoSize),
              SizedBox(width: microCompact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'NOVA',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: microCompact ? 12.6 : 13.4,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ligada ao contexto',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: microCompact ? 10.8 : 11.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: microCompact ? 6 : 8),
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    if (showBriefing) ...[
                      SizedBox(height: microCompact ? 6 : 8),
                      Text(
                        briefing,
                        maxLines: microCompact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: briefingFontSize,
                          height: 1.38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              statePill(),
            ],
          ),
          if (showActions) ...[
            SizedBox(height: microCompact ? 10 : 12),
            if (microCompact)
              Column(
                children: actions
                    .take(actionLimit)
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: actionChip(action, expand: true),
                      ),
                    )
                    .toList(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions
                    .take(actionLimit)
                    .map((action) => actionChip(action))
                    .toList(),
              ),
          ],
          if (!microCompact && !compressed) ...[
            const SizedBox(height: 10),
            Text(
              '${line.timestamp.hour.toString().padLeft(2, '0')}:${line.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.76),
                fontSize: 11.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryPanel({
    bool compact = false,
    bool spotlight = false,
  }) {
    final memoryItems = _memoryRailItems();
    final documentItems = _documentHighlights();
    final colors = context.novaColors;

    return GlassContainer(
      borderRadius: 30,
      blur: 20,
      opacity: context.isNovaDark ? 0.16 : 0.26,
      borderColor: spotlight
          ? colors.primary.withValues(alpha: context.isNovaDark ? 0.34 : 0.22)
          : null,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spotlight) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primarySoft.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Retomada rápida',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Memória ativa',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 16 : 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _systemStatus,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: compact ? 12.0 : 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          if (memoryItems.isEmpty)
            Text(
              'As últimas memórias e documentos processados aparecem aqui para acelerar a retomada.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 12.6 : 13.2,
                height: 1.5,
              ),
            )
          else
            ...memoryItems.take(3).map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                    child: Text(
                      '• $item',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: compact ? 12.4 : 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
          if (documentItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Documentos',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: compact ? 13.8 : 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...documentItems.take(3).map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: compact ? 6 : 8),
                    child: Text(
                      '• $item',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: compact ? 12.2 : 12.8,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarColumn({
    bool compact = false,
    bool spotlight = false,
  }) {
    return Column(
      children: [
        NovaSidebarBio(
          statusLabel: _assistantState.label,
          contextText: _conversationContextLabel(),
          onOpenMemory: _openBrainDialog,
          compact: compact,
          spotlight: spotlight,
        ),
        SizedBox(height: compact ? 12 : 14),
        _buildMemoryPanel(
          compact: compact,
          spotlight: spotlight,
        ),
      ],
    );
  }

  Widget _buildTabletSidebarBand({
    required double width,
    required bool portrait,
  }) {
    final useTwoColumns = width >= 860;
    if (portrait) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: NovaSidebarBio(
              statusLabel: _assistantState.label,
              contextText: _conversationContextLabel(),
              onOpenMemory: _openBrainDialog,
              compact: width < 920,
              spotlight: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                NovaModulesPanel(
                  modules: _contextModules(),
                  onModuleTap: _handleModuleTap,
                  compact: true,
                  spotlight: true,
                ),
                const SizedBox(height: 12),
                _buildMemoryPanel(
                  compact: true,
                  spotlight: true,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (!useTwoColumns) {
      return _buildSidebarColumn(
        compact: true,
        spotlight: true,
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NovaSidebarBio(
                statusLabel: _assistantState.label,
                contextText: _conversationContextLabel(),
                onOpenMemory: _openBrainDialog,
                compact: true,
                spotlight: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: NovaModulesPanel(
                modules: _contextModules(),
                onModuleTap: _handleModuleTap,
                compact: true,
                spotlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMemoryPanel(
          compact: true,
          spotlight: true,
        ),
      ],
    );
  }

  Widget _buildMainColumn({
    required bool compact,
    required bool compressed,
    required bool microCompact,
    required bool ultrawide,
    bool wideChat = false,
  }) {
    final topGap =
        compressed ? 10.0 : (ultrawide ? 14.0 : (microCompact ? 8.0 : 12.0));
    final composerGap = compressed ? 10.0 : (microCompact ? 8.0 : 14.0);
    return Column(
      children: [
        NovaTopBar(
          onMenuTap: _openQuickMenu,
          onUserTap: _openUsersDialog,
          onCameraTap: _pickQuickPhoto,
          contextText: _conversationContextLabel(),
          status: _assistantState,
        ),
        SizedBox(height: topGap),
        Expanded(
          child: _buildChatThread(
            compact: compact || microCompact,
            wideChat: wideChat,
            smallMobile: microCompact,
            ultrawide: ultrawide,
          ),
        ),
        SizedBox(height: composerGap),
        NovaChatInput(
          controller: _messageController,
          attachmentName: _composerAttachment?.name,
          onRemoveAttachment: _composerAttachment == null
              ? null
              : () {
                  setState(() => _composerAttachment = null);
                },
          isListening: _isListening,
          sending: _sending || _preparingAttachment,
          compact: compact || compressed || microCompact,
          onAdd: _pickComposerAttachment,
          onMic: _speechReady ? _toggleListening : _initSpeech,
          onSend: _handleSendMessage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shellMaxWidth = screenWidth >= 1700
        ? 980.0
        : (screenWidth >= 1500
            ? 920.0
            : (screenWidth >= 1200
                ? 760.0
                : (screenWidth >= 900
                    ? 680.0
                    : (screenWidth >= 600 ? 560.0 : screenWidth))));
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const NovaGridBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final isUltrawide =
                    viewport.maxWidth >= 1680 && viewport.maxHeight >= 780;
                final useWideLayout =
                    viewport.maxWidth >= 1180 && viewport.maxHeight >= 720;
                final useStackedSidebarLayout = !useWideLayout &&
                    viewport.maxWidth >= 760 &&
                    viewport.maxHeight >= 760;
                final isTabletPortrait = useStackedSidebarLayout &&
                    viewport.maxHeight > viewport.maxWidth;
                final compressed = viewport.maxHeight < 650;
                final chatShell = ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: shellMaxWidth),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      final microCompact = constraints.maxWidth < 400;
                      final wideChat = constraints.maxWidth >= 680;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          microCompact ? 6 : 10,
                          microCompact ? 6 : 8,
                          microCompact ? 6 : 10,
                          microCompact ? 8 : 10,
                        ),
                        child: _buildMainColumn(
                          compact: compact,
                          compressed: compressed,
                          microCompact: microCompact,
                          ultrawide: isUltrawide,
                          wideChat: wideChat,
                        ),
                      );
                    },
                  ),
                );

                if (useStackedSidebarLayout) {
                  final sidebarHeight = isTabletPortrait
                      ? (viewport.maxHeight >= 900 ? 340.0 : 300.0)
                      : (viewport.maxHeight >= 900 ? 320.0 : 260.0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(child: chatShell),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: sidebarHeight,
                          width: double.infinity,
                          child: SingleChildScrollView(
                            child: _buildTabletSidebarBand(
                              width: viewport.maxWidth - 28,
                              portrait: isTabletPortrait,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!useWideLayout) {
                  return Center(child: chatShell);
                }

                final sidebarWidth = viewport.maxWidth >= 1680
                    ? 388.0
                    : (viewport.maxWidth >= 1480 ? 348.0 : 304.0);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    viewport.maxWidth >= 1680 ? 26 : 18,
                    12,
                    viewport.maxWidth >= 1680 ? 26 : 18,
                    16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: isUltrawide
                              ? Alignment.centerRight
                              : Alignment.center,
                          child: chatShell,
                        ),
                      ),
                      SizedBox(width: isUltrawide ? 24 : 18),
                      SizedBox(
                        width: sidebarWidth,
                        child: SingleChildScrollView(
                          child: _buildSidebarColumn(
                            spotlight: isUltrawide,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
