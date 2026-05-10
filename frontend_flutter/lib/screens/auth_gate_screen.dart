import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/api_endpoint_config.dart';
import '../services/chat_api.dart';
import '../theme/colors.dart';
import '../widgets/glass_container.dart';
import '../widgets/home/dialog_widgets.dart' show NovaDialogContent;
import '../widgets/home/chat_shell_widgets.dart' show NovaGridBackground;
import '../widgets/nova_sidebar_bio.dart' show NovaMetalLogo;

typedef AuthConnectionChanged = Future<void> Function({
  required String apiBaseUrl,
  required String apiToken,
});

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.onAuthenticated,
    this.initialApiBaseUrl = '',
    this.initialApiToken = '',
    this.onConnectionChanged,
  });

  final ValueChanged<AuthSession> onAuthenticated;
  final String initialApiBaseUrl;
  final String initialApiToken;
  final AuthConnectionChanged? onConnectionChanged;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerEmailController =
      TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();
  final TextEditingController _registerConfirmController =
      TextEditingController();
  late final ChatApiService _api;
  late String _configuredApiBaseUrl;
  late String _configuredApiToken;

  bool _registerMode = false;
  bool _submitting = false;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _registerConfirmVisible = false;
  String _feedback = '';
  String _connectionFeedback = '';

  @override
  void initState() {
    super.initState();
    _configuredApiBaseUrl = widget.initialApiBaseUrl.trim();
    _configuredApiToken = widget.initialApiToken.trim();
    _api = ChatApiService(
      baseUrl: _configuredApiBaseUrl,
      apiToken: _configuredApiToken,
    );
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailController =
        _registerMode ? _registerEmailController : _loginEmailController;
    final passwordController =
        _registerMode ? _registerPasswordController : _loginPasswordController;
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _feedback = 'Preencha email e senha para continuar.');
      return;
    }

    if (_registerMode) {
      final name = _registerNameController.text.trim();
      if (name.length < 2) {
        setState(() => _feedback = 'Informe seu nome para criar a conta.');
        return;
      }
      if (password.length < 8) {
        setState(
          () => _feedback = 'A senha precisa ter pelo menos 8 caracteres.',
        );
        return;
      }
      if (password != _registerConfirmController.text) {
        setState(() => _feedback = 'A confirmação da senha não confere.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _feedback = '';
    });

    try {
      final session = _registerMode
          ? await _api.registerUser(
              name: _registerNameController.text.trim(),
              email: email,
              password: password,
            )
          : await _api.loginUser(
              email: email,
              password: password,
            );
      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (error) {
      if (!mounted) return;
      var message = error.toString().replaceFirst('Exception: ', '');
      if (message.contains('Falha de conexão com a API') ||
          message.contains('Tempo esgotado ao conectar com a API')) {
        message =
            '$message Verifique se o backend está ligado e revise a URL em "Configurar API".';
      }
      setState(() => _feedback = message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _apiConnectionSummary {
    if (_configuredApiBaseUrl.isEmpty) {
      return 'Auto-detect ativo. Endpoint atual: ${_api.baseUrl}';
    }
    return 'API manual: ${_api.baseUrl}';
  }

  Future<void> _openConnectionDialog() async {
    final apiBaseUrlController = TextEditingController(
      text: _configuredApiBaseUrl,
    );
    final apiTokenController = TextEditingController(
      text: _configuredApiToken,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var dialogFeedback = _connectionFeedback;
        var busy = false;

        Future<void> testConnection(StateSetter setLocalState) async {
          final rawBaseUrl = apiBaseUrlController.text.trim();
          final normalizedBaseUrl = ApiEndpointConfig.normalizeBaseUrl(
            rawBaseUrl,
          );
          if (rawBaseUrl.isNotEmpty && normalizedBaseUrl.isEmpty) {
            setLocalState(() {
              dialogFeedback =
                  'URL inválida. Use algo como ${ApiEndpointConfig.exampleManualBaseUrl()}.';
            });
            return;
          }

          setLocalState(() {
            busy = true;
            dialogFeedback = 'Testando conexão...';
          });

          try {
            final probe = ChatApiService(
              baseUrl: normalizedBaseUrl,
              apiToken: apiTokenController.text.trim(),
            );
            final health = await probe.discoverBackend(
              explicitBaseUrl:
                  normalizedBaseUrl.isEmpty ? null : normalizedBaseUrl,
            );
            final reachable =
                health['reachable'] == true || health['ok'] == true;
            setLocalState(() {
              dialogFeedback = reachable
                  ? 'Conexão OK em ${health['base_url'] ?? probe.baseUrl}.'
                  : (health['message']?.toString() ??
                      'Não foi possível encontrar um backend ativo.');
            });
          } catch (error) {
            setLocalState(() {
              dialogFeedback = error
                  .toString()
                  .replaceFirst('Exception: ', '')
                  .replaceAll('\n', ' ');
            });
          } finally {
            setLocalState(() => busy = false);
          }
        }

        Future<void> saveConnection(StateSetter setLocalState) async {
          final rawBaseUrl = apiBaseUrlController.text.trim();
          final normalizedBaseUrl = ApiEndpointConfig.normalizeBaseUrl(
            rawBaseUrl,
          );
          if (rawBaseUrl.isNotEmpty && normalizedBaseUrl.isEmpty) {
            setLocalState(() {
              dialogFeedback =
                  'URL inválida. Use algo como ${ApiEndpointConfig.exampleManualBaseUrl()}.';
            });
            return;
          }

          setLocalState(() => busy = true);
          try {
            await widget.onConnectionChanged?.call(
              apiBaseUrl: normalizedBaseUrl,
              apiToken: apiTokenController.text.trim(),
            );
            _configuredApiBaseUrl = normalizedBaseUrl;
            _configuredApiToken = apiTokenController.text.trim();
            _api.updateConnection(
              baseUrl: _configuredApiBaseUrl,
              apiToken: _configuredApiToken,
            );
            if (!mounted) return;
            setState(() {
              _connectionFeedback = normalizedBaseUrl.isEmpty
                  ? 'Auto-detect reativado para a API.'
                  : 'API configurada para ${_api.baseUrl}.';
              if (_feedback.contains('Falha de conexão com a API') ||
                  _feedback.contains('Tempo esgotado ao conectar com a API')) {
                _feedback = '';
              }
            });
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          } finally {
            if (dialogContext.mounted) {
              setLocalState(() => busy = false);
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final colors = context.novaColors;
            return AlertDialog(
              backgroundColor: colors.surface,
              title: const Text('Conexão com API'),
              content: NovaDialogContent(
                maxWidth: 420,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para celular físico, use o IP da máquina onde a API está rodando. Ex.: ${ApiEndpointConfig.exampleManualBaseUrl('192.168.0.114')}.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: apiBaseUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'URL da API',
                        hintText: ApiEndpointConfig.exampleManualBaseUrl(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiTokenController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Token da API',
                        hintText: 'Opcional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dialogFeedback.isEmpty
                          ? 'Deixe a URL vazia para usar o auto-detect da plataforma.'
                          : dialogFeedback,
                      style: TextStyle(
                        color: dialogFeedback.startsWith('Conexão OK')
                            ? const Color(0xFF0F9D58)
                            : colors.textSecondary,
                        fontSize: 12.8,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: busy ? null : () => testConnection(setLocalState),
                  child: const Text('Testar'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => saveConnection(setLocalState),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    apiBaseUrlController.dispose();
    apiTokenController.dispose();
  }

  void _setRegisterMode(bool value) {
    setState(() {
      _registerMode = value;
      _feedback = '';
    });
  }

  Widget _buildModeToggle(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.26 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Entrar',
              selected: !_registerMode,
              onTap: () => _setRegisterMode(false),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Criar conta',
              selected: _registerMode,
              onTap: () => _setRegisterMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputShell(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    bool isPasswordVisible = false,
    bool autocorrect = true,
    Iterable<String>? autofillHints,
    VoidCallback? onToggleVisibility,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: context.isNovaDark ? 0.07 : 0.62),
            colors.surface.withValues(alpha: context.isNovaDark ? 0.20 : 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.glassBorder.withValues(
            alpha: context.isNovaDark ? 0.56 : 0.92,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.18 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText && !isPasswordVisible,
              autocorrect: autocorrect,
              enableSuggestions: !obscureText,
              autofillHints: autofillHints,
              onSubmitted: onSubmitted,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15.2,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: colors.textSecondary.withValues(alpha: 0.92),
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
            ),
          ),
          if (onToggleVisibility != null)
            IconButton(
              onPressed: onToggleVisibility,
              splashRadius: 20,
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool compact}) {
    final colors = context.novaColors;
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.52),
            colors.surface.withValues(alpha: context.isNovaDark ? 0.16 : 0.80),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        border: Border.all(
          color: colors.glassBorder.withValues(
            alpha: context.isNovaDark ? 0.44 : 0.90,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: context.isNovaDark ? 0.24 : 0.08,
            ),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeToggle(context),
          SizedBox(height: compact ? 18 : 22),
          Text(
            _registerMode ? 'Crie sua conta NOVA' : 'Entre na sua conta',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _registerMode
                ? 'Cadastre nome, email e senha para começar com uma experiência mais pronta para uso final.'
                : 'Use seu email e senha para retomar o contexto, memória e preferências da NOVA.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: compact ? 13.0 : 13.8,
              height: 1.5,
            ),
          ),
          SizedBox(height: compact ? 18 : 22),
          AutofillGroup(
            child: Column(
              children: [
                if (_registerMode) ...[
                  _buildInputShell(
                    context,
                    controller: _registerNameController,
                    hintText: 'Seu nome de exibição',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInputShell(
                  context,
                  controller: _registerMode
                      ? _registerEmailController
                      : _loginEmailController,
                  hintText: 'Email',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),
                _buildInputShell(
                  context,
                  controller: _registerMode
                      ? _registerPasswordController
                      : _loginPasswordController,
                  hintText: 'Senha',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  isPasswordVisible: _registerMode
                      ? _registerPasswordVisible
                      : _loginPasswordVisible,
                  textInputAction: _registerMode
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  onToggleVisibility: () {
                    setState(() {
                      if (_registerMode) {
                        _registerPasswordVisible = !_registerPasswordVisible;
                      } else {
                        _loginPasswordVisible = !_loginPasswordVisible;
                      }
                    });
                  },
                  onSubmitted: (_) {
                    if (!_registerMode) _submit();
                  },
                ),
                if (_registerMode) ...[
                  const SizedBox(height: 12),
                  _buildInputShell(
                    context,
                    controller: _registerConfirmController,
                    hintText: 'Confirmar senha',
                    icon: Icons.verified_user_outlined,
                    obscureText: true,
                    isPasswordVisible: _registerConfirmVisible,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newPassword],
                    onToggleVisibility: () {
                      setState(() {
                        _registerConfirmVisible = !_registerConfirmVisible;
                      });
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ],
            ),
          ),
          if (_registerMode) ...[
            const SizedBox(height: 12),
            Text(
              'Use uma senha forte para ativar sua experiência premium com segurança desde o primeiro acesso.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 12.2 : 12.8,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: context.isNovaDark ? 0.05 : 0.42,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conexão com API',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _apiConnectionSummary,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.6,
                    height: 1.4,
                  ),
                ),
                if (_connectionFeedback.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _connectionFeedback,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.2,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _openConnectionDialog,
                    icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                    label: const Text('Configurar API'),
                  ),
                ),
              ],
            ),
          ),
          if (_feedback.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _feedback,
              style: const TextStyle(
                color: Color(0xFFD92D20),
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: compact ? 18 : 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(compact ? 54 : 58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_registerMode ? 'Criar conta' : 'Entrar'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _registerMode
                  ? 'Conta criada para sincronizar memória, contexto e personalidade.'
                  : 'Acesso seguro para continuar exatamente de onde você parou.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 12.1 : 12.6,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, {required bool compact}) {
    final colors = context.novaColors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? 0 : 640,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: context.isNovaDark ? 0.08 : 0.42,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Text(
              'Workspace premium NOVA',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: compact ? 11.6 : 12.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(height: compact ? 18 : 22),
          Row(
            children: [
              NovaMetalLogo(size: compact ? 74 : 86),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'NOVA',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 26 : 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 28),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 540 : 460),
            child: Text(
              'NOVA — sofisticada por design, poderosa por inteligência.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: compact ? 26 : 34,
                fontWeight: FontWeight.w800,
                height: 1.08,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 560 : 500),
            child: Text(
              'Entre com sua conta para manter contexto, memória, personalidade e fluxo de trabalho sincronizados desde o primeiro acesso.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 13.6 : 15.2,
                height: 1.58,
              ),
            ),
          ),
          if (!compact) const Spacer(),
          SizedBox(height: compact ? 22 : 0),
          Container(
            constraints:
                BoxConstraints(maxWidth: compact ? double.infinity : 460),
            padding: EdgeInsets.all(compact ? 16 : 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: context.isNovaDark ? 0.06 : 0.34,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 40 : 44,
                  height: compact ? 40 : 44,
                  decoration: BoxDecoration(
                    color: colors.primarySoft.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    size: compact ? 20 : 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uma conta, todos os seus dispositivos',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: compact ? 14.2 : 15.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Android, iOS, web e desktop com a mesma memória, o mesmo contexto e a mesma personalidade ativa.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: compact ? 12.6 : 13.2,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedPanel(BuildContext context, {required bool compact}) {
    final colors = context.novaColors;
    final divider = compact
        ? Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 22),
            color: colors.glassBorder.withValues(
              alpha: context.isNovaDark ? 0.36 : 0.72,
            ),
          )
        : Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: colors.glassBorder.withValues(
              alpha: context.isNovaDark ? 0.30 : 0.70,
            ),
          );

    return GlassContainer(
      borderRadius: compact ? 32 : 40,
      blur: 28,
      opacity: context.isNovaDark ? 0.18 : 0.30,
      padding: EdgeInsets.zero,
      child: Container(
        constraints: BoxConstraints(
          minHeight: compact ? 0 : 760,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: compact ? 180 : 260,
                  height: compact ? 180 : 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.brandGlow.withValues(alpha: 0.22),
                        colors.brandGlow.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: IgnorePointer(
                child: Container(
                  width: compact ? 220 : 320,
                  height: compact ? 220 : 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(
                          alpha: context.isNovaDark ? 0.04 : 0.22,
                        ),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 18 : 28),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(context, compact: true),
                        divider,
                        _buildForm(context, compact: true),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 6, 18, 6),
                            child: _buildHero(context, compact: false),
                          ),
                        ),
                        divider,
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 10,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: _buildForm(context, compact: false),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const NovaGridBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1100;
                final panel = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? 720 : 1220,
                  ),
                  child: _buildUnifiedPanel(context, compact: compact),
                );

                if (compact) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Center(child: panel),
                  );
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: panel,
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : Colors.white.withValues(alpha: context.isNovaDark ? 0.0 : 0.02),
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.26),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textPrimary,
              fontSize: 13.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
