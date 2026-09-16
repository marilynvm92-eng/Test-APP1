import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // A device token is an address, not a credential. Do not log it.
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "mynews.apnsToken")
        // Production integration: send to the authenticated device endpoint described in Backend/PUSH.md.
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        UserDefaults.standard.set("No se pudo registrar este dispositivo en APNs.", forKey: "mynews.apnsError")
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let value = response.notification.request.content.userInfo["articleURL"] as? String,
           let url = URL(string: value), url.scheme == "https", url.host != nil {
            UserDefaults.standard.set(value, forKey: "mynews.pendingArticleURL")
            NotificationCenter.default.post(name: .myNewsOpenArticle, object: nil)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let myNewsOpenArticle = Notification.Name("mynews.openArticle")
}
