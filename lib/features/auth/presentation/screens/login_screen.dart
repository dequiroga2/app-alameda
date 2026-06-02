import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/wave_header.dart';
import '../widgets/login_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final connectivity = ref.read(connectivityStreamProvider);
    if (isOfflineFromStream(connectivity)) {
      setState(() => _error = 'Sin conexión. Conéctate a internet e intenta de nuevo.');
      return;
    }

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = _mapAuthError(e.message));
    } catch (_) {
      setState(() => _error = 'Error de conexión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login')) return 'Email o contraseña incorrectos.';
    if (msg.contains('Email not confirmed')) return 'Tu cuenta aún no está aprobada.';
    return 'No se pudo iniciar sesión. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final connectivity = ref.watch(connectivityStreamProvider);
    final offline = isOfflineFromStream(connectivity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WaveHeader(
                    solid: true,
                    backgroundColor: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(26, top + 28, 26, 8),
                      child: Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: const Icon(Icons.sports_tennis_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 18),
                          Text('La Alameda', style: AppTextStyles.displayLg.copyWith(color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('Reserva de zonas comunes',
                              style: AppTextStyles.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                    child: AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Ingresar', style: AppTextStyles.headlineSm),
                          const SizedBox(height: 22),

                          const FieldLabel(label: 'Correo electrónico'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _emailCtrl,
                            hint: 'tu@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),

                          const FieldLabel(label: 'Contraseña'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _passCtrl,
                            hint: 'Tu contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.textFaint, size: 20,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.errorTint, borderRadius: BorderRadius.circular(10)),
                              child: Text(_error!,
                                  style: AppTextStyles.labelMd.copyWith(color: AppColors.error)),
                            ),
                            const SizedBox(height: 16),
                          ],

                          AppButton(
                            label: 'Ingresar',
                            onPressed: offline ? null : _login,
                            size: AppButtonSize.lg,
                            fullWidth: true,
                            loading: _loading,
                            icon: Icons.login_rounded,
                          ),
                          const SizedBox(height: 16),

                          TextButton(
                            onPressed: offline ? null : () => context.push('/register'),
                            child: Text(
                              offline
                                  ? 'Necesitas conexión para registrarte'
                                  : '¿Primera vez? Solicitar acceso',
                              style: AppTextStyles.labelLg.copyWith(
                                color: offline ? AppColors.textFaint : AppColors.accentDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text('Conjunto Residencial La Alameda',
                        textAlign: TextAlign.center, style: AppTextStyles.caption),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
