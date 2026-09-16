import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet {
            store.write(preferences, key: "preferences")
            if oldValue.country != preferences.country || oldValue.notificationCategories != preferences.notificationCategories ||
                !preferences.notificationsEnabled { notifications.cancelPending() }
        }
    }
    @Published private(set) var saved: [NewsArticle]
    @Published var storageMessage: String?
    let notifications: NotificationService
    let service: any NewsServiceProtocol
    let cache = NewsCache()
    let isDemo: Bool
    let serviceNamespace: String
    private let store: LocalStore

    init(store: LocalStore? = nil) {
        let store = store ?? LocalStore()
        self.store = store
        preferences = store.read(UserPreferences.self, key: "preferences") ?? UserPreferences()
        saved = store.read([NewsArticle].self, key: "saved") ?? []
        notifications = NotificationService(store: store)
        let base = (Bundle.main.object(forInfoDictionaryKey: "NewsBackendURL") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty, !base.hasPrefix("$("), let url = URL(string: base), url.scheme == "https", url.host != nil {
            service = RealNewsService(baseURL: url)
            isDemo = false
            serviceNamespace = url.absoluteString
        } else {
            service = MockNewsService()
            isDemo = true
            serviceNamespace = "demo-v1"
            if !base.isEmpty && !base.hasPrefix("$(") {
                storageMessage = "La URL del backend no es HTTPS válida. Se inició el modo de ejemplo."
            }
        }
    }
    var colorScheme: ColorScheme? {
        switch preferences.appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var feedKey: String {
        serviceNamespace + "|" + preferences.country + "|" + preferences.categories.map(\.rawValue).sorted().joined(separator: ",")
    }
    func isSaved(_ article: NewsArticle) -> Bool { saved.contains { $0.id == article.id || $0.canonicalURL == article.canonicalURL } }
    func toggleSaved(_ article: NewsArticle) {
        if isSaved(article) { saved.removeAll { $0.id == article.id || $0.canonicalURL == article.canonicalURL } }
        else {
            guard saved.count < 500 else { storageMessage = "Puedes guardar hasta 500 noticias. Elimina alguna para continuar."; return }
            saved.insert(article, at: 0)
        }
        store.write(saved, key: "saved")
    }
    func resetPreferences() {
        notifications.cancelPending()
        preferences = UserPreferences()
        // Keep bookmarks and notification deduplication history.
        Task { await cache.clear() }
    }
}
