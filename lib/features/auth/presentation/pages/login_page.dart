import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/google_sign_in_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.repository, this.googleSignInService});

  final AuthRepository? repository;
  final GoogleSignInService? googleSignInService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final _repository = widget.repository ?? AuthRepository();
  late final _googleSignIn =
      widget.googleSignInService ?? GoogleSignInService();
  bool _isGoogleSubmitting = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting || _isGoogleSubmitting) return;

    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _isSubmitting = true);
    var message = 'No pudimos identificar el tipo de cuenta.';
    AuthUser? user;
    try {
      final result = await _repository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      user = result.user;
      if (mounted) _passwordController.clear();
    } on ApiException catch (error) {
      message = error.message;
    } on NetworkException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'No pudimos iniciar sesión. Intenta nuevamente.';
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    _finishLogin(user, message);
  }

  Future<void> _submitGoogle() async {
    if (_isSubmitting || _isGoogleSubmitting) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _isGoogleSubmitting = true);
    AuthUser? user;
    var message = 'No pudimos identificar el tipo de cuenta.';
    try {
      final idToken = await _googleSignIn.signIn();
      if (idToken == null || !mounted) return;
      final result = await _repository.loginWithGoogle(idToken: idToken);
      user = result.user;
      if (mounted) _passwordController.clear();
    } on ApiException catch (error) {
      message = error.message;
    } on NetworkException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'No pudimos iniciar sesión. Intenta nuevamente.';
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
    if (mounted) _finishLogin(user, message);
  }

  void _finishLogin(AuthUser? user, String message) {
    final route = switch (user?.role) {
      'patient' => AppRoutes.patientDashboard,
      'therapist' => AppRoutes.therapistDashboard,
      _ => null,
    };
    if (route != null) {
      Navigator.of(context).pushReplacementNamed(route, arguments: user);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 36),

                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    size: 38,
                    color: AppTheme.primary,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Papatzoa',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Tu espacio de bienestar emocional',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  'Bienvenido de nuevo',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Ingresa a tu cuenta para continuar.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 28),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Ingresa tu correo electrónico.';
                    }
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email)) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@correo.com',
                    prefixIcon: const Icon(Icons.mail_outline),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu contraseña.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: null,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSubmitting || _isGoogleSubmitting
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                              semanticsLabel: 'Iniciando sesión',
                            ),
                          )
                        : const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('o continúa con'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 18),

                OutlinedButton.icon(
                  onPressed: _isSubmitting || _isGoogleSubmitting
                      ? null
                      : _submitGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isGoogleSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Iniciando sesión con Google',
                          ),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '¿Aún no tienes cuenta?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 18),

                OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Crear una cuenta'),
                ),

                const SizedBox(height: 40),

                Text(
                  'Tu información se maneja de forma privada y segura.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
