import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones locales.
/// - iOS: llama directo a UNUserNotificationCenter vía MethodChannel nativo.
/// - Android: usa flutter_local_notifications.
class NotificationService {
  // ── iOS: canal nativo ─────────────────────────────────────────────────────
  static const _iosChannel = MethodChannel('com.laalameda/notifications');

  // ── Android: plugin ───────────────────────────────────────────────────────
  static final _androidPlugin = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Callback que se ejecuta cuando el usuario pulsa una notificación.
  /// Regístralo desde main_shell_screen para navegar a la pantalla correcta.
  static VoidCallback? onTapped;

  static Future<void> init() async {
    if (_initialized) return;

    if (Platform.isIOS) {
      // Escuchar el tap de notificación desde Swift
      _iosChannel.setMethodCallHandler((call) async {
        if (call.method == 'onTapped') {
          debugPrint('🔔 Notification tapped — navigating');
          onTapped?.call();
        }
      });
      try {
        final granted = await _iosChannel.invokeMethod<bool>('requestPermission');
        debugPrint('🔔 iOS permission granted: $granted');
      } catch (e) {
        debugPrint('🔔 iOS permission error: $e');
      }
    } else if (Platform.isAndroid) {
      const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _androidPlugin.initialize(
        const InitializationSettings(android: settings),
      );
      await _androidPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    try {
      if (Platform.isIOS) {
        // Llama al método nativo en AppDelegate.swift
        await _iosChannel.invokeMethod<void>('show', {
          'title': title,
          'body': body,
        });
      } else {
        const androidDetails = AndroidNotificationDetails(
          'la_alameda_reservas',
          'Reservas La Alameda',
          channelDescription: 'Notificaciones de reservas y sorteos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        await _androidPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
          title,
          body,
          const NotificationDetails(android: androidDetails),
        );
      }
      debugPrint('🔔 NotificationService.show() completed');
    } catch (e) {
      debugPrint('🔔 NotificationService.show() error: $e');
    }
  }
}
