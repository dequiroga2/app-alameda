import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/wave_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final top = MediaQuery.of(context).padding.top;

    final name = user?.userMetadata?['full_name']?.toString() ?? 'Residente';
    final tower = user?.userMetadata?['tower']?.toString() ?? '';
    final apt = user?.userMetadata?['apartment']?.toString() ?? '';
    final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: WaveHeader(
              backgroundColor: AppColors.background,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, top + 16, 24, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accentStrong,
                      child: Text(initials,
                          style: AppTextStyles.headlineSm.copyWith(color: Colors.white, fontSize: 22)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.headlineSm),
                        if (tower.isNotEmpty && apt.isNotEmpty)
                          Text('Torre $tower · Apto $apt', style: AppTextStyles.bodyMd),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ToggleRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notificaciones',
                        subtitle: 'Recordatorios de tus reservas',
                        value: _notifications,
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                      _Divider(),
                      _MenuRow(icon: Icons.language_rounded, label: 'Idioma', detail: 'Español'),
                      _Divider(),
                      _MenuRow(icon: Icons.shield_outlined, label: 'Reglas de uso'),
                      _Divider(),
                      _MenuRow(icon: Icons.help_outline_rounded, label: 'Ayuda y soporte'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Resumen de reglas
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reglas de la cancha',
                          style: AppTextStyles.titleMd.copyWith(color: AppColors.accentDeep)),
                      const SizedBox(height: 10),
                      ...[
                        'Máximo ${AppConstants.weeklyReservationLimit} reservas por semana',
                        'Solo 1 reserva por día',
                        'Bloques de 1 hora, de 7 a.m. a 9 p.m.',
                      ].map((rule) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                const Icon(Icons.check_rounded,
                                    color: AppColors.accentStrong, size: 17),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(rule,
                                      style: AppTextStyles.labelMd.copyWith(
                                          color: AppColors.accentDeep)),
                                ),
                              ],
                            ),
                          )),
                ],
              ),
            ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Cerrar sesión',
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  variant: AppButtonVariant.danger,
                  fullWidth: true,
                  icon: Icons.logout_rounded,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.titleMd),
                Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentStrong,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.detail});
  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppTextStyles.titleMd)),
          if (detail != null) Text(detail!, style: AppTextStyles.bodyMd),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 18),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppColors.accentStrong, size: 20),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 14, endIndent: 14);
  }
}
