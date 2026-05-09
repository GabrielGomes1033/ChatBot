import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/chat_api.dart';
import '../theme/colors.dart';
import '../widgets/glass_container.dart';
import '../widgets/home/chat_shell_widgets.dart' show NovaGridBackground;
import '../widgets/nova_sidebar_bio.dart' show NovaMetalLogo;

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.onAuthenticated,
  });

  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final ChatApiService _api = ChatApiService();
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

  bool _registerMode = false;
  bool _submitting = false;
  String _feedback = '';

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
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() => _feedback = message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildModeToggle(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isNovaDark ? 0.06 : 0.40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Entrar',
              selected: !_registerMode,
              onTap: () => setState(() => _registerMode = false),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Criar conta',
              selected: _registerMode,
              onTap: () => setState(() => _registerMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool compact}) {
    final colors = context.novaColors;
    return GlassContainer(
      borderRadius: compact ? 26 : 32,
      blur: 24,
      opacity: context.isNovaDark ? 0.16 : 0.28,
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          if (_registerMode) ...[
            TextField(
              controller: _registerNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Seu nome de exibição',
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _registerMode
                ? _registerEmailController
                : _loginEmailController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'voce@empresa.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _registerMode
                ? _registerPasswordController
                : _loginPasswordController,
            obscureText: true,
            textInputAction:
                _registerMode ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) {
              if (!_registerMode) _submit();
            },
            decoration: const InputDecoration(
              labelText: 'Senha',
              hintText: 'Mínimo de 8 caracteres',
            ),
          ),
          if (_registerMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _registerConfirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                hintText: 'Repita a senha',
              ),
            ),
          ],
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
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, {required bool compact}) {
    final colors = context.novaColors;
    return GlassContainer(
      borderRadius: compact ? 28 : 34,
      blur: 24,
      opacity: context.isNovaDark ? 0.16 : 0.24,
      padding: EdgeInsets.all(compact ? 20 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NovaMetalLogo(size: compact ? 72 : 84),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'NOVA',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 26 : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 24),
          Text(
            'Uma experiência premium, pronta para Android, iOS, web e desktop.',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Entre com sua conta para manter contexto, memória, personalidade e fluxo de trabalho sincronizados desde o primeiro acesso.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: compact ? 13.2 : 14.2,
              height: 1.55,
            ),
          ),
          SizedBox(height: compact ? 18 : 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(label: 'Chat natural'),
              _InfoPill(label: 'Pesquisa objetiva'),
              _InfoPill(label: 'Memória ativa'),
              _InfoPill(label: 'Layout responsivo'),
            ],
          ),
        ],
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
                final compact = constraints.maxWidth < 940;
                final content = compact
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          children: [
                            _buildHero(context, compact: true),
                            const SizedBox(height: 16),
                            _buildForm(context, compact: true),
                          ],
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _buildHero(context, compact: false),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 10,
                                  child: _buildForm(context, compact: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                return content;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textPrimary,
              fontSize: 13.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.novaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isNovaDark ? 0.08 : 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 12.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
