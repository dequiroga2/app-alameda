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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  String _tower = '1';
  final _unitCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _done = false;

  // Cache: guardamos el texto cuando se pierde conexión para no perder el progreso
  String _cachedUnit = '';
  String _cachedName = '';
  String _cachedEmail = '';

  bool get _isCasa => _tower == 'Casa';

  @override
  void initState() {
    super.initState();
    _unitCtrl.addListener(() => _cachedUnit = _unitCtrl.text);
    _nameCtrl.addListener(() => _cachedName = _nameCtrl.text);
    _emailCtrl.addListener(() => _cachedEmail = _emailCtrl.text);
  }

  @override
  void dispose() {
    _unitCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _restoreCache() {
    if (_unitCtrl.text.isEmpty && _cachedUnit.isNotEmpty) _unitCtrl.text = _cachedUnit;
    if (_nameCtrl.text.isEmpty && _cachedName.isNotEmpty) _nameCtrl.text = _cachedName;
    if (_emailCtrl.text.isEmpty && _cachedEmail.isNotEmpty) _emailCtrl.text = _cachedEmail;
  }

  Future<void> _register() async {
    final connectivity = ref.read(connectivityStreamProvider);
    if (isOfflineFromStream(connectivity)) {
      setState(() => _error = 'Sin conexión. Tus datos están guardados — intenta cuando vuelva la señal.');
      return;
    }

    final unit = _unitCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    if (unit.isEmpty || name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {
          'full_name': name,
          'tower': _tower,
          'apartment': unit,
          'unit_type': _isCasa ? 'casa' : 'apartamento',
          'status': 'pending',
          'role': 'resident',
        },
      );

      if (res.user != null) setState(() => _done = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message.contains('already registered')
          ? 'Ya existe una cuenta con este correo.'
          : 'Error Supabase: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Error de conexión. Tus datos están guardados, intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final connectivity = ref.watch(connectivityStreamProvider);
    final offline = isOfflineFromStream(connectivity);

    // Si vuelve la conexión, restauramos los campos cacheados
    if (!offline) _restoreCache();

    if (_done) return _SuccessView(onBack: () => context.go('/login'));

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
                    backgroundColor: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accentDeep),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Solicitar acceso', style: AppTextStyles.headlineSm),
                              Text('La aprobación tarda 1–2 días hábiles', style: AppTextStyles.bodyMd),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                    child: AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tus datos', style: AppTextStyles.titleLg),
                          const SizedBox(height: 20),

                          const FieldLabel(label: 'Nombre completo'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _nameCtrl,
                            hint: 'Ej. Laura Gómez',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 18),

                          const FieldLabel(label: 'Torre'),
                          const SizedBox(height: 8),
                          TowerSelector(
                            selected: _tower,
                            onChanged: (v) => setState(() {
                              _tower = v;
                              _unitCtrl.clear();
                            }),
                          ),
                          const SizedBox(height: 18),

                          FieldLabel(label: _isCasa ? 'Número de casa (1 – 48)' : 'Apartamento'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _unitCtrl,
                            hint: _isCasa ? 'Ej. 12' : 'Ej. 402',
                            icon: _isCasa ? Icons.home_outlined : Icons.apartment_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 18),

                          const FieldLabel(label: 'Correo electrónico'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _emailCtrl,
                            hint: 'tu@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: AppColors.accentDeep, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cada residente de la misma unidad puede tener su propio correo. '
                                    'Las 3 reservas semanales son compartidas por unidad.',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.accentDeep, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          const FieldLabel(label: 'Contraseña'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _passCtrl,
                            hint: 'Mínimo 8 caracteres',
                            icon: Icons.lock_outline_rounded,
                            obscure: true,
                          ),
                          const SizedBox(height: 18),

                          const FieldLabel(label: 'Confirmar contraseña'),
                          const SizedBox(height: 8),
                          AppInput(
                            controller: _pass2Ctrl,
                            hint: 'Repite la contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscure: true,
                          ),
                          const SizedBox(height: 24),

                          if (offline) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi_off_rounded,
                                      color: AppColors.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sin conexión. Tus datos están guardados — espera la señal para enviar.',
                                      style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.errorTint,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(_error!,
                                  style: AppTextStyles.labelMd.copyWith(color: AppColors.error)),
                            ),
                            const SizedBox(height: 16),
                          ],

                          AppButton(
                            label: 'Enviar solicitud',
                            onPressed: offline ? null : _register,
                            size: AppButtonSize.lg,
                            fullWidth: true,
                            loading: _loading,
                            icon: Icons.send_rounded,
                          ),
                        ],
                      ),
                    ),
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.accentTint, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.accentStrong, size: 52),
              ),
              const SizedBox(height: 24),
              Text('¡Solicitud enviada!',
                  style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'El administrador del conjunto revisará tu solicitud. '
                'Recibirás una notificación cuando sea aprobada (1–2 días hábiles).',
                style: AppTextStyles.bodyLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                  label: 'Volver al inicio', onPressed: onBack,
                  fullWidth: true, size: AppButtonSize.lg),
            ],
          ),
        ),
      ),
    );
  }
}
