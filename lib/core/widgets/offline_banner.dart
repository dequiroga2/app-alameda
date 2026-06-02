import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Muestra un banner rojo cuando no hay conexión.
/// Úsalo con [showBanner: true] dentro de pantallas que requieren red.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(connectivityStreamProvider);
    final isOffline = stream.whenOrNull(
          data: (result) => result.contains(ConnectivityResult.none),
        ) ??
        false;

    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.error,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — algunas funciones no están disponibles',
              style: AppTextStyles.labelSm.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retorna true si actualmente no hay conexión según el stream de Riverpod.
bool isOfflineFromStream(AsyncValue<List<ConnectivityResult>> stream) {
  return stream.whenOrNull(
        data: (result) => result.contains(ConnectivityResult.none),
      ) ??
      false;
}
