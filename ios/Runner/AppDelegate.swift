import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

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
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {

        case "requestPermission":
          UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
          ) { granted, error in
            DispatchQueue.main.async {
              if let error = error {
                print("🔔 Permission error: \(error)")
              }
              print("🔔 iOS permission granted: \(granted)")
              result(granted)
            }
          }

        case "show":
          guard
            let args = call.arguments as? [String: String],
            let title = args["title"],
            let body = args["body"]
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

  private func scheduleNotification(title: String, body: String, flutterResult: @escaping FlutterResult) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body  = body
    content.sound = .default
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .active
    }

    // Trigger de 0.5 s — suficiente para que willPresent se llame correctamente
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    let id      = "la-alameda-\(Int(Date().timeIntervalSince1970))"
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async {
        if let error = error {
          print("🔔 Error scheduling notification: \(error.localizedDescription)")
          flutterResult(FlutterError(code: "NOTIF_ERROR", message: error.localizedDescription, details: nil))
        } else {
          print("🔔 Notification scheduled OK — id: \(id)")
          flutterResult(nil)
        }
      }
    }
  }

  // Sin este override FlutterAppDelegate responde UNNotificationPresentationOptionNone
  // → ningún banner aparece cuando la app está en foreground.
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

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
