import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/home/presentation/screens/main_shell_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/confirm_screen.dart';

part 'app_router.g.dart';

// Convierte el stream de auth en un Listenable estable para GoRouter.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    _sub = ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription _sub;

  bool get isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pending',
        name: 'pending',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/book',
            name: 'book',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/my-reservations',
            name: 'my-reservations',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
      GoRoute(
        path: '/booking/:amenityId',
        name: 'booking',
        builder: (context, state) => BookingScreen(
          amenityId: state.pathParameters['amenityId']!,
        ),
      ),
      GoRoute(
        path: '/confirm',
        name: 'confirm',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ConfirmScreen(
            reservationId: extra['reservationId'] as String,
            amenityName: extra['amenityName'] as String,
            date: extra['date'] as DateTime,
            hour: extra['hour'] as int,
          );
        },
      ),
    ],
  );
}
