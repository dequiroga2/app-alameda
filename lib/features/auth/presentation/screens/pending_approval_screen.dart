import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: AppColors.warning, size: 40),
              ),
              const SizedBox(height: 24),
              Text('Solicitud en revisión',
                  style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'El administrador del conjunto está revisando tu solicitud. Esto toma 1–2 días hábiles.',
                style: AppTextStyles.bodyLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Cerrar sesión',
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => Supabase.instance.client.auth.signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
