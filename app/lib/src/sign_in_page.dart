import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'account.dart';
import 'app_state.dart';
import 'theme.dart';

enum SignInReason { general, follow, log }

enum _Mode { signIn, create, reset }

/// Sign in, create an account, or reset a password. Pops `true` once signed in.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.reason = SignInReason.general});

  final SignInReason reason;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  bool get _showApple => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _password.addListener(() {
      if (_mode == _Mode.create) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _title => switch (_mode) {
        _Mode.signIn => 'Welcome back',
        _Mode.create => 'Create your account',
        _Mode.reset => 'Reset your password',
      };

  String get _subtitle => switch (_mode) {
        _Mode.reset => "Enter your account's email and we'll send a link to choose a new password.",
        _ => switch (widget.reason) {
            SignInReason.follow => 'Sign in to follow this launch and get alerts when it slips, changes status, or lifts off.',
            SignInReason.log => 'Sign in to keep a log of the launches you have watched.',
            SignInReason.general => 'Follow launches, get alerts, and keep your log in sync across devices. Browsing never needs an account.',
          },
      };

  void _switch(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
        _notice = null;
      });

  Future<void> _run(Future<void> Function() action, {bool closeOnSuccess = true}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (closeOnSuccess) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final account = LaunchWatchScope.of(context);
    switch (_mode) {
      case _Mode.signIn:
        await _run(() => account.signIn(_email.text, _password.text));
      case _Mode.create:
        await _run(() => account.createAccount(name: _name.text, email: _email.text, password: _password.text));
        if (mounted && account.signedIn) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created. Check ${_email.text.trim()} to verify your email.')));
        }
      case _Mode.reset:
        await _run(() => account.sendPasswordReset(_email.text), closeOnSuccess: false);
        if (mounted && _error == null) {
          setState(() => _notice = 'If an account exists for ${_email.text.trim()}, a reset link is on its way. Check your spam folder too.');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    const _Mark(),
                    const SizedBox(height: 20),
                    Semantics(header: true, child: Text(_title, style: text.headlineMedium)),
                    const SizedBox(height: 8),
                    Text(_subtitle, style: text.bodyMedium?.copyWith(color: launchInkMuted)),
                    const SizedBox(height: 24),
                    if (_mode != _Mode.reset) ...[
                      _ProviderButton(
                        label: 'Continue with Google',
                        icon: const _GoogleG(),
                        onPressed: _busy ? null : () => _run(account.signInWithGoogle),
                      ),
                      if (_showApple) ...[
                        const SizedBox(height: 10),
                        _ProviderButton(label: 'Continue with Apple', icon: const Icon(Icons.apple, size: 22), onPressed: _busy ? null : () => _run(account.signInWithApple)),
                      ],
                      const SizedBox(height: 20),
                      const Row(children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or with email', style: TextStyle(color: launchInkFaint, fontSize: 12.5))),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 20),
                    ],
                    if (_mode == _Mode.create) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Name (optional)'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: _mode == _Mode.reset ? TextInputAction.done : TextInputAction.next,
                      onFieldSubmitted: _mode == _Mode.reset ? (_) => _submit() : null,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    if (_mode != _Mode.reset) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: [_mode == _Mode.create ? AutofillHints.newPassword : AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (_mode == _Mode.create) return passwordProblem(password);
                          if (password.isEmpty) return 'Enter your password';
                          return null;
                        },
                      ),
                      if (_mode == _Mode.create) _StrengthMeter(password: _password.text),
                      if (_mode == _Mode.signIn)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () => _switch(_Mode.reset), child: const Text('Forgot password?')),
                        ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _Message(text: _error!, error: true),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _Message(text: _notice!, error: false),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: launchActionInk))
                          : Text(switch (_mode) { _Mode.signIn => 'Sign in', _Mode.create => 'Create account', _Mode.reset => 'Send reset link' }),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: switch (_mode) {
                        _Mode.signIn => TextButton(onPressed: () => _switch(_Mode.create), child: const Text('New to LaunchWatch? Create an account')),
                        _Mode.create => TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('Already have an account? Sign in')),
                        _Mode.reset => TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('Back to sign in')),
                      },
                    ),
                    if (_mode == _Mode.create)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'We only use your email to sign you in and, if you choose, to send launch alerts. You can delete your account and all of its data at any time from Account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: launchInkFaint, fontSize: 12, height: 1.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: launchSurfaceRaised, borderRadius: BorderRadius.circular(12), border: Border.all(color: launchLineStrong)),
        child: const Icon(Icons.rocket_launch, color: launchAccent, size: 22),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: launchSurface),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(width: 10), Text(label)]),
    );
  }
}

/// The Google "G", drawn so no image asset is needed.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800, fontSize: 13, height: 1)),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox(height: 8);
    final score = passwordStrength(password);
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    const colors = [Color(0xFFFF6B6B), Color(0xFFFF9B54), Color(0xFFF2B84B), Color(0xFF7FD6A8), Color(0xFF4ED69A)];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: i < score ? colors[score] : launchLine, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 6),
        Text(labels[score], style: TextStyle(color: colors[score], fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFFF6B6B) : const Color(0xFF4ED69A);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline : Icons.mark_email_read_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
        ]),
      ),
    );
  }
}
