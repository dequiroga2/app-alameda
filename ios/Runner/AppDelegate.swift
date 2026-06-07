import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Guardamos referencia al canal para usarla desde didReceive
  private var notifChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Nos aseguramos de ser el delegate DESPUÉS de que super y los plugins hayan corrido
    UNUserNotificationCenter.current().delegate = self

    // Method channel: bypass flutter_local_notifications en iOS
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.laalameda/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      notifChannel = channel

      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {

        case "requestPermission":
          UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
          ) { granted, error in
            DispatchQueue.main.async {
              if let error = error { print("🔔 Permission error: \(error)") }
              print("🔔 iOS permission granted: \(granted)")
              result(granted)
            }
          }

        case "show":
          guard
            let args = call.arguments as? [String: String],
            let title = args["title"],
            let body  = args["body"]
          else {
            result(FlutterError(code: "INVALID_ARGS", message: "title/body required", details: nil))
            return
          }
          self?.scheduleNotification(title: title, body: body, flutterResult: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return result
  }

  // MARK: - Schedule notification

  private func scheduleNotification(title: String, body: String, flutterResult: @escaping FlutterResult) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body  = body
    content.sound = .default
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .active
    }

    // Trigger de 0.5 s — garantiza que willPresent se invoque correctamente
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    let id      = "la-alameda-\(Int(Date().timeIntervalSince1970))"
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async {
        if let error = error {
          print("🔔 Error scheduling: \(error.localizedDescription)")
          flutterResult(FlutterError(code: "NOTIF_ERROR", message: error.localizedDescription, details: nil))
        } else {
          print("🔔 Notification scheduled OK — id: \(id)")
          flutterResult(nil)
        }
      }
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Sin este override, FlutterAppDelegate llama completionHandler([]) → sin banner en foreground.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("🔔 [AppDelegate] willPresent — id: \(notification.request.identifier)")
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  /// El usuario pulsó la notificación → avisar a Flutter para navegar a Mis Reservas.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("🔔 [AppDelegate] didReceive (tap) — id: \(response.notification.request.identifier)")
    // Pequeño delay para que Flutter esté listo si la app estaba en background
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.notifChannel?.invokeMethod("onTapped", arguments: nil)
    }
    completionHandler()
  }
}
