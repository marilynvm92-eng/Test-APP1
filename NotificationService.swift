import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published var message: String?
    private let center = UNUserNotificationCenter.current()
    private let store: LocalStore
    private var isScheduling = false
    private var revision = 0
    init(store: LocalStore) { self.store = store }
    var allowed: Bool { status == .authorized || status == .provisional || status == .ephemeral }
    func refreshStatus() async { status = await center.notificationSettings().authorizationStatus }
    func requestPermission() async -> Bool {
        do {
            let result = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
            if !result { message = "Puedes permitir las notificaciones desde los ajustes de iOS." }
            return result
        } catch {
            message = "No pudimos solicitar el permiso: \(error.localizedDescription)"
            return false
        }
    }
    func cancelPending() {
        revision += 1
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    func test(preferences: UserPreferences) async {
        let requestRevision = revision
        await refreshStatus()
        guard requestRevision == revision else { return }
        guard preferences.notificationsEnabled, allowed else {
            message = "Activa las notificaciones y concede el permiso de iOS primero."
            return
        }
        guard let category = preferences.notificationCategories.sorted(by: { $0.rawValue < $1.rawValue }).first else {
            message = "Selecciona al menos una categoría para las notificaciones."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Prueba · \(category.title)"
        content.body = "Así recibirás noticias de \(Country(id: preferences.country).name). Esta es una prueba."
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: "mynews-test", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            guard requestRevision == revision else {
                center.removePendingNotificationRequests(withIdentifiers: ["mynews-test"])
                return
            }
            message = "Prueba programada para dentro de 5 segundos."
        } catch { message = "No pudimos programar la prueba." }
    }
    // Called only for newly fetched real news while the app is open.
    // The backend will apply equivalent rules when the app is closed.
    func scheduleBreaking(_ articles: [NewsArticle], preferences: UserPreferences) async {
        guard !isScheduling else { return }
        isScheduling = true
        defer { isScheduling = false }
        let requestRevision = revision
        await refreshStatus()
        guard allowed, preferences.notificationsEnabled, requestRevision == revision else { return }
        var history = store.read([String: Date].self, key: "notified") ?? [:]
        history = history.filter { Date().timeIntervalSince($0.value) < 30 * 24 * 3600 }
        let last = store.read(Date.self, key: "lastNotification") ?? .distantPast
        guard let article = NotificationPolicy.candidate(in: articles, preferences: preferences,
                                                        history: history, lastNotification: last) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(article.category.title) · Última hora"
        content.body = article.title
        content.sound = .default
        content.userInfo = ["articleURL": article.articleURL.absoluteString]
        do {
            try await center.add(UNNotificationRequest(identifier: article.id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
            guard requestRevision == revision else {
                center.removePendingNotificationRequests(withIdentifiers: [article.id])
                return
            }
            history[article.id] = Date()
            store.write(history, key: "notified")
            store.write(Date(), key: "lastNotification")
        } catch { message = "No pudimos programar el aviso de última hora." }
    }
}
