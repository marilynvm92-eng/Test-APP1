# Código Swift completo

Cada encabezado indica la ruta exacta desde la raíz del proyecto. Los archivos ya están creados y agregados al target de Xcode. Consulta FASES.md para explicación y pruebas.

## MyNews/App/AppDelegate.swift

```swift
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
```

## MyNews/App/MyNewsApp.swift

```swift
import SwiftUI

@main
@MainActor
struct MyNewsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}
```

## MyNews/App/RootView.swift

```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationLink: BrowserLink?
    var body: some View {
        Group {
            if app.preferences.onboardingCompleted {
                TabView {
                    HomeView().tabItem { Label("Home", systemImage: "house.fill") }
                    ExploreView().tabItem { Label("Explorar", systemImage: "magnifyingglass") }
                    SavedView().tabItem { Label("Guardados", systemImage: "bookmark.fill") }
                    SettingsView().tabItem { Label("Configuración", systemImage: "gearshape.fill") }
                }
            } else { OnboardingView() }
        }
        .tint(.indigo)
        .preferredColorScheme(app.colorScheme)
        .task { await app.notifications.refreshStatus(); openPendingLink() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { Task { await app.notifications.refreshStatus() }; openPendingLink() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myNewsOpenArticle).receive(on: RunLoop.main)) { _ in openPendingLink() }
        .sheet(item: $notificationLink) { SafariView(url: $0.url).ignoresSafeArea() }
        .alert("MyNews", isPresented: Binding(get: { app.storageMessage != nil }, set: { if !$0 { app.storageMessage = nil } })) {
            Button("Aceptar") { app.storageMessage = nil }
        } message: { Text(app.storageMessage ?? "") }
    }
    private func openPendingLink() {
        guard let value = UserDefaults.standard.string(forKey: "mynews.pendingArticleURL"),
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return }
        notificationLink = BrowserLink(url: url)
        UserDefaults.standard.removeObject(forKey: "mynews.pendingArticleURL")
    }
}

#Preview { RootView().environmentObject(AppState()) }
```

## MyNews/Components/ArticleCard.swift

```swift
import SwiftUI

struct ArticleImage: View {
    let url: URL?
    var height: CGFloat = 200
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url?.scheme == "https" ? url : nil) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        LinearGradient(colors: [.indigo.opacity(0.2), .teal.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "newspaper").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
            }.frame(width: geometry.size.width, height: height).clipped()
        }.frame(height: height).accessibilityHidden(true)
    }
}

struct ArticleCard: View {
    let article: NewsArticle
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleImage(url: article.imageURL)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(article.category.title, systemImage: article.category.symbol).foregroundStyle(.indigo)
                    Spacer()
                    if article.isBreakingNews { Text("ÚLTIMA HORA").foregroundStyle(.red).font(.caption2.bold()) }
                }.font(.caption.bold())
                Text(article.title).font(.title3.bold()).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(article.source).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(article.publishedAt, style: .relative)
                    Spacer()
                    Text(article.country.map { Country(id: $0).name } ?? "Internacional")
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(18)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct NewsListContent: View {
    @ObservedObject var model: NewsListViewModel
    let retry: () async -> Void
    var body: some View {
        if model.loading {
            ProgressView("Cargando noticias…").frame(maxWidth: .infinity).padding(60)
        } else if model.articles.isEmpty {
            if let message = model.errorMessage {
                ContentUnavailableView {
                    Label("No pudimos cargar las noticias", systemImage: "wifi.exclamationmark")
                } description: { Text(message) } actions: {
                    Button("Intentar nuevamente") { Task { await retry() } }.buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView("Sin resultados", systemImage: "newspaper", description: Text("Prueba otro tema o una búsqueda diferente."))
            }
        } else {
            if let date = model.cacheDate {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Mostrando noticias guardadas en caché", systemImage: "wifi.slash")
                    Text("Actualizadas \(date.formatted(date: .abbreviated, time: .shortened))")
                    Text(model.errorMessage ?? "")
                    Button("Intentar nuevamente") { Task { await retry() } }
                }.font(.caption).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(model.articles) { article in
                NavigationLink { ArticleDetailView(article: article) } label: { ArticleCard(article: article) }.buttonStyle(.plain)
            }
        }
    }
}
```

## MyNews/Components/PreferencePickers.swift

```swift
import SwiftUI

struct CountryPicker: View {
    @Binding var selection: String
    @State private var query = ""
    private var countries: [Country] {
        Country.all.filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
    }
    var body: some View {
        List(countries) { country in
            Button { selection = country.id } label: {
                HStack {
                    Text(country.flag).font(.title2).accessibilityHidden(true)
                    Text(country.name).foregroundStyle(.primary)
                    Spacer()
                    if selection == country.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo) }
                }.padding(.vertical, 6)
            }.accessibilityAddTraits(selection == country.id ? .isSelected : [])
        }
        .searchable(text: $query, prompt: "Buscar país")
        .overlay { if countries.isEmpty { ContentUnavailableView.search(text: query) } }
        .navigationTitle("Tu país")
    }
}

struct CategoryPicker: View {
    @Binding var selection: Set<NewsCategory>
    var minimumOne = false
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(NewsCategory.allCases) { category in
                let selected = selection.contains(category)
                Button {
                    if selected {
                        if !minimumOne || selection.count > 1 { selection.remove(category) }
                    } else { selection.insert(category) }
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: category.symbol).font(.title2)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        }
                        Text(category.title).font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.padding()
    }
}
```

## MyNews/Models/NewsArticle.swift

```swift
import Foundation

struct NewsArticle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String
    let imageURL: URL?
    let articleURL: URL
    let source: String
    let publishedAt: Date
    let category: NewsCategory
    let country: String?
    let isBreakingNews: Bool

    var safeArticleURL: URL? {
        guard ["https", "http"].contains(articleURL.scheme?.lowercased() ?? ""),
              articleURL.host != nil else { return nil }
        return articleURL
    }

    var canonicalURL: String {
        guard var parts = URLComponents(url: articleURL, resolvingAgainstBaseURL: false) else {
            return articleURL.absoluteString
        }
        parts.fragment = nil
        parts.host = parts.host?.lowercased()
        parts.queryItems = parts.queryItems?.filter {
            !$0.name.lowercased().hasPrefix("utm_") && !["fbclid", "gclid"].contains($0.name.lowercased())
        }.sorted { $0.name < $1.name }
        if parts.queryItems?.isEmpty == true { parts.queryItems = nil }
        return parts.string ?? articleURL.absoluteString
    }
}
```

## MyNews/Models/Preferences.swift

```swift
import Foundation

enum NewsCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case breaking, sports, technology, science, economy, business
    case entertainment, health, politics, world, culture, gaming
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breaking: "Última hora"
        case .sports: "Deportes"
        case .technology: "Tecnología"
        case .science: "Ciencia"
        case .economy: "Economía"
        case .business: "Negocios"
        case .entertainment: "Entretenimiento"
        case .health: "Salud"
        case .politics: "Política"
        case .world: "Mundo"
        case .culture: "Cultura"
        case .gaming: "Videojuegos"
        }
    }
    var symbol: String {
        switch self {
        case .breaking: "bolt.fill"
        case .sports: "sportscourt.fill"
        case .technology: "desktopcomputer"
        case .science: "atom"
        case .economy: "chart.line.uptrend.xyaxis"
        case .business: "briefcase.fill"
        case .entertainment: "film.fill"
        case .health: "heart.fill"
        case .politics: "building.columns.fill"
        case .world: "globe.americas.fill"
        case .culture: "theatermasks.fill"
        case .gaming: "gamecontroller.fill"
        }
    }
}

struct Country: Identifiable, Hashable, Sendable {
    let id: String
    var name: String { Locale(identifier: "es").localizedString(forRegionCode: id) ?? id }
    var flag: String {
        String(String.UnicodeScalarView(id.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }
    static let all: [Country] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.unicodeScalars.allSatisfy { (65...90).contains($0.value) } }
        .map { Country(id: $0) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "Sistema"; case .light: "Claro"; case .dark: "Oscuro" }
    }
}

struct UserPreferences: Codable, Equatable {
    var country = "CR"
    var categories: Set<NewsCategory> = []
    var notificationCategories: Set<NewsCategory> = []
    var notificationsEnabled = false
    var appearance: Appearance = .system
    var onboardingCompleted = false
}
```

## MyNews/Networking/HTTPClient.swift

```swift
import Foundation

struct HTTPClient: Sendable {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func get<T: Decodable & Sendable>(_ type: T.Type, url: URL) async throws -> T {
        guard url.scheme == "https", url.host != nil else { throw NewsError.configuration }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw NewsError.invalidResponse }
            switch response.statusCode {
            case 200...299: break
            case 401, 403: throw NewsError.invalidKey
            case 429: throw NewsError.rateLimited
            default: throw NewsError.server(response.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NewsError.decoding }
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            if [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut].contains(error.code) {
                throw NewsError.offline
            }
            throw NewsError.invalidResponse
        }
    }
}
```

## MyNews/Networking/NewsError.swift

```swift
import Foundation

enum NewsError: LocalizedError {
    case offline, server(Int), invalidResponse, decoding, invalidKey, rateLimited, configuration
    var errorDescription: String? {
        switch self {
        case .offline: "No hay conexión a internet."
        case .server: "El servidor no está disponible. Inténtalo más tarde."
        case .invalidResponse: "El servidor devolvió una respuesta inválida."
        case .decoding: "No pudimos interpretar las noticias recibidas."
        case .invalidKey: "El servicio no está autorizado. Revisa la configuración del servidor."
        case .rateLimited: "Se alcanzó el límite del servicio. Inténtalo más tarde."
        case .configuration: "Configura una dirección HTTPS válida para el backend."
        }
    }
}
```

## MyNews/Services/News/MockNewsService.swift

```swift
import Foundation

struct MockNewsService: NewsServiceProtocol {
    private func articles(country: String) -> [NewsArticle] {
        let headlines: [NewsCategory: String] = [
            .breaking: "La actualidad del día, en un vistazo",
            .sports: "El deporte local se prepara para una nueva temporada",
            .technology: "Nuevas ideas de inteligencia artificial llegan a las aulas",
            .science: "Un proyecto científico explora la biodiversidad",
            .economy: "Las claves para entender la economía esta semana",
            .business: "Pequeños negocios apuestan por el comercio digital",
            .entertainment: "El cine reúne nuevas historias y talentos",
            .health: "Hábitos cotidianos para una vida activa",
            .politics: "Una guía para seguir el debate público",
            .world: "Las historias internacionales para empezar el día",
            .culture: "El arte transforma los espacios de la ciudad",
            .gaming: "Los videojuegos independientes exploran nuevas ideas"
        ]
        return NewsCategory.allCases.enumerated().flatMap { index, category in
            (0..<3).map { variant in
                let id = "demo-\(country)-\(category.rawValue)-\(variant)"
                return NewsArticle(
                    id: id,
                    title: (headlines[category] ?? category.title) + (variant == 1 ? ": mirada internacional" : variant == 2 ? ": en contexto" : ""),
                    description: "Esta es una noticia ficticia para probar MyNews. No describe un hecho verificado. Aquí aparecerá el resumen autorizado por la fuente, junto con el enlace a la publicación original.",
                    imageURL: URL(string: "https://picsum.photos/seed/\(category.rawValue)-\(variant)/900/600"),
                    articleURL: URL(string: "https://example.com/news/\(id)")!,
                    source: "MyNews · Demostración",
                    publishedAt: Date().addingTimeInterval(-Double(index * 420 + variant * 3600)),
                    category: category, country: variant == 1 ? nil : country,
                    isBreakingNews: category == .breaking || (variant == 0 && category == .sports)
                )
            }
        }
    }
    func fetchTopHeadlines(country: String, categories: [String]) async throws -> [NewsArticle] {
        try await Task.sleep(for: .milliseconds(250))
        return FeedRanker.personalize(articles(country: country), country: country,
                                     categories: Set(categories.compactMap(NewsCategory.init(rawValue:))))
    }
    func fetchNews(category: String, country: String) async throws -> [NewsArticle] {
        try await fetchTopHeadlines(country: country, categories: [category])
    }
    func searchNews(query: String) async throws -> [NewsArticle] {
        try await Task.sleep(for: .milliseconds(250))
        return ["CR", "US", "ES", "MX", "AR", "CO", "BR"].flatMap { articles(country: $0) }.filter {
            "\($0.title) \($0.category.title) \(Country(id: $0.country ?? "").name)"
                .localizedStandardContains(query)
        }
    }
}
```

## MyNews/Services/News/NewsService.swift

```swift
import Foundation

protocol NewsServiceProtocol: Sendable {
    func fetchTopHeadlines(country: String, categories: [String]) async throws -> [NewsArticle]
    func fetchNews(category: String, country: String) async throws -> [NewsArticle]
    func searchNews(query: String) async throws -> [NewsArticle]
}

enum FeedRanker {
    static func personalize(_ articles: [NewsArticle], country: String, categories: Set<NewsCategory>) -> [NewsArticle] {
        let filtered = articles.filter {
            (categories.contains($0.category) || (categories.contains(.breaking) && $0.isBreakingNews)) &&
            ($0.country?.uppercased() == country.uppercased() || $0.country == nil || $0.isBreakingNews)
        }
        // Publication day first, local stories within the day, then exact date.
        // This keeps yesterday's local news below today's international news.
        let calendar = Calendar(identifier: .gregorian)
        let sorted = filtered.sorted { lhs, rhs in
            let leftDay = calendar.startOfDay(for: lhs.publishedAt)
            let rightDay = calendar.startOfDay(for: rhs.publishedAt)
            if leftDay != rightDay { return leftDay > rightDay }
            let leftLocal = lhs.country?.uppercased() == country.uppercased()
            let rightLocal = rhs.country?.uppercased() == country.uppercased()
            if leftLocal != rightLocal { return leftLocal }
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt > rhs.publishedAt }
            return lhs.id < rhs.id
        }
        return unique(sorted)
    }

    static func unique(_ articles: [NewsArticle]) -> [NewsArticle] {
        var ids = Set<String>()
        var urls = Set<String>()
        return articles.filter {
            guard $0.safeArticleURL != nil, !ids.contains($0.id), !urls.contains($0.canonicalURL) else { return false }
            ids.insert($0.id)
            urls.insert($0.canonicalURL)
            return true
        }
    }
}
```

## MyNews/Services/News/RealNewsService.swift

```swift
import Foundation

// Calls our provider-independent backend. Provider API keys never enter the app.
struct RealNewsService: NewsServiceProtocol {
    let baseURL: URL
    let client: HTTPClient
    init(baseURL: URL, client: HTTPClient = HTTPClient()) {
        self.baseURL = baseURL
        self.client = client
    }
    private struct Response: Decodable, Sendable { let articles: [NewsArticle] }
    private func fetch(path: String, parameters: [URLQueryItem]) async throws -> [NewsArticle] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NewsError.configuration
        }
        components.queryItems = parameters
        guard let url = components.url else { throw NewsError.configuration }
        let result = try await client.get(Response.self, url: url)
        return FeedRanker.unique(result.articles.sorted { $0.publishedAt > $1.publishedAt })
    }
    func fetchTopHeadlines(country: String, categories: [String]) async throws -> [NewsArticle] {
        try await fetch(path: "v1/headlines", parameters: [
            .init(name: "country", value: country),
            .init(name: "categories", value: categories.sorted().joined(separator: ","))
        ])
    }
    func fetchNews(category: String, country: String) async throws -> [NewsArticle] {
        try await fetchTopHeadlines(country: country, categories: [category])
    }
    func searchNews(query: String) async throws -> [NewsArticle] {
        try await fetch(path: "v1/search", parameters: [.init(name: "q", value: query)])
    }
}
```

## MyNews/Services/Notifications/NotificationPolicy.swift

```swift
import Foundation

enum NotificationPolicy {
    static func candidate(in articles: [NewsArticle], preferences: UserPreferences,
                          history: [String: Date], lastNotification: Date,
                          now: Date = Date(), calendar: Calendar = .current) -> NewsArticle? {
        guard preferences.notificationsEnabled,
              now.timeIntervalSince(lastNotification) >= 3600,
              history.values.filter({ calendar.isDate($0, inSameDayAs: now) }).count < 3 else { return nil }
        return articles.filter {
            $0.isBreakingNews && preferences.notificationCategories.contains($0.category) &&
            ($0.country == nil || $0.country?.uppercased() == preferences.country.uppercased()) &&
            now.timeIntervalSince($0.publishedAt) >= 0 && now.timeIntervalSince($0.publishedAt) < 6 * 3600 &&
            history[$0.id] == nil
        }.sorted { $0.publishedAt > $1.publishedAt }.first
    }
}
```

## MyNews/Services/Notifications/NotificationService.swift

```swift
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
```

## MyNews/Services/Storage/LocalStore.swift

```swift
import Foundation

@MainActor
final class LocalStore {
    private let defaults: UserDefaults
    private let prefix = "mynews.v1."
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: prefix + key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: prefix + key)
    }
    func remove(_ key: String) { defaults.removeObject(forKey: prefix + key) }
}
```

## MyNews/Services/Storage/NewsCache.swift

```swift
import Foundation
import CryptoKit

actor NewsCache {
    struct Entry: Codable, Sendable {
        let articles: [NewsArticle]
        let savedAt: Date
    }
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyNews", isDirectory: true)
    }
    private func file(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }
    func read(_ key: String) -> Entry? {
        guard let data = try? Data(contentsOf: file(key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < 7 * 24 * 3600 else { return nil }
        return entry
    }
    func write(_ articles: [NewsArticle], key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Entry(articles: Array(articles.prefix(100)), savedAt: Date()))
            try data.write(to: file(key), options: .atomic)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            let sorted = files.sorted {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
                ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
            for old in sorted.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
        } catch { /* Cache failure must not hide successfully loaded news. */ }
    }
    func clear() { try? FileManager.default.removeItem(at: directory) }
}
```

## MyNews/ViewModels/AppState.swift

```swift
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
```

## MyNews/ViewModels/NewsListViewModel.swift

```swift
import Foundation
import Combine

@MainActor
final class NewsListViewModel: ObservableObject {
    @Published private(set) var articles: [NewsArticle] = []
    @Published private(set) var loading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var cacheDate: Date?
    private var generation = UUID()

    func load(key: String, cache: NewsCache,
              operation: () async throws -> [NewsArticle]) async {
        let request = UUID()
        generation = request
        loading = true
        errorMessage = nil
        cacheDate = nil
        articles = []
        do {
            let result = try await operation()
            try Task.checkCancellation()
            guard generation == request else { return }
            articles = FeedRanker.unique(result)
            await cache.write(articles, key: key)
        } catch {
            guard generation == request, !Task.isCancelled, !(error is CancellationError) else {
                if generation == request { loading = false }
                return
            }
            let cached = await cache.read(key)
            guard generation == request, !Task.isCancelled else { return }
            if let cached { articles = cached.articles; cacheDate = cached.savedAt }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No pudimos cargar las noticias."
        }
        if generation == request { loading = false }
    }
}
```

## MyNews/Views/Detail/ArticleDetailView.swift

```swift
import SwiftUI
import SafariServices

struct BrowserLink: Identifiable { let id = UUID(); let url: URL }

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct ArticleDetailView: View {
    @EnvironmentObject private var app: AppState
    let article: NewsArticle
    @State private var link: BrowserLink?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ArticleImage(url: article.imageURL, height: 260).clipShape(RoundedRectangle(cornerRadius: 22))
                Label(article.category.title, systemImage: article.category.symbol).font(.subheadline.bold()).foregroundStyle(.indigo)
                Text(article.title).font(.system(.largeTitle, design: .serif, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.source).font(.headline)
                    Text(article.publishedAt.formatted(date: .long, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(article.description).font(.body).lineSpacing(6)
                if article.id.hasPrefix("demo-") {
                    Text("Contenido ficticio: el enlace abre una página de ejemplo.").font(.caption).foregroundStyle(.secondary)
                }
                if let url = article.safeArticleURL {
                    Button { link = BrowserLink(url: url) } label: {
                        Label("Leer noticia completa", systemImage: "safari").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                    Text("La publicación completa pertenece a su fuente original.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding()
        }.navigationTitle("Noticia").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let url = article.safeArticleURL { ShareLink(item: url) { Label("Compartir", systemImage: "square.and.arrow.up") } }
                    Button { app.toggleSaved(article) } label: {
                        Label(app.isSaved(article) ? "Quitar de guardados" : "Guardar", systemImage: app.isSaved(article) ? "bookmark.fill" : "bookmark")
                    }
                }
            }.sheet(item: $link) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}
```

## MyNews/Views/Explore/ExploreView.swift

```swift
import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var model = NewsListViewModel()
    @State private var query = ""
    @State private var category: NewsCategory = .breaking
    private var cleanQuery: String { String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)) }
    private var requestKey: String { app.serviceNamespace + "|" + app.preferences.country + "|" + category.rawValue + "|" + cleanQuery }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if cleanQuery.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(NewsCategory.allCases) { item in
                                    Button { category = item } label: {
                                        Label(item.title, systemImage: item.symbol).font(.subheadline.bold())
                                            .padding(12).background(category == item ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                                            .foregroundStyle(category == item ? Color.white : Color.primary)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if app.isDemo { Text("Datos ficticios de demostración").font(.caption).foregroundStyle(.secondary) }
                    NewsListContent(model: model, retry: load)
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Explorar")
                .searchable(text: $query, prompt: "Buscar noticias")
                .task(id: requestKey) { await load() }
                .refreshable { await load() }
        }
    }
    private func load() async {
        let term = cleanQuery
        let selected = category
        let country = app.preferences.country
        await model.load(key: "explore|" + requestKey, cache: app.cache) {
            if !term.isEmpty {
                try await Task.sleep(for: .milliseconds(350))
                return try await app.service.searchNews(query: term)
            }
            return try await app.service.fetchNews(category: selected.rawValue, country: country)
        }
    }
}
```

## MyNews/Views/Home/HomeView.swift

```swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var model = NewsListViewModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).font(.subheadline).foregroundStyle(.secondary)
                        Text("Tu selección de hoy").font(.system(.largeTitle, design: .serif, weight: .bold))
                        Label(Country(id: app.preferences.country).name, systemImage: "location.fill").font(.subheadline).foregroundStyle(.indigo)
                        if app.isDemo {
                            Label("Modo de ejemplo · Noticias ficticias", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    NewsListContent(model: model, retry: load)
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("MyNews").navigationBarTitleDisplayMode(.inline)
                .refreshable { await load() }
                .task(id: app.feedKey) { await load() }
        }
    }
    private func load() async {
        let preferences = app.preferences
        await model.load(key: "home|" + app.feedKey, cache: app.cache) {
            let articles = try await app.service.fetchTopHeadlines(country: preferences.country, categories: preferences.categories.map(\.rawValue))
            return FeedRanker.personalize(articles, country: preferences.country, categories: preferences.categories)
        }
        if !Task.isCancelled, !app.isDemo, model.errorMessage == nil, app.preferences == preferences {
            await app.notifications.scheduleBreaking(model.articles, preferences: app.preferences)
        }
    }
}
```

## MyNews/Views/Onboarding/OnboardingView.swift

```swift
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var step = 0
    @State private var requesting = false
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0:
                    introduction(symbol: "newspaper.fill", title: "Tu mundo.\nTus noticias.", subtitle: "Noticias que realmente te interesan.")
                case 1: CountryPicker(selection: $app.preferences.country)
                case 2:
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("¿Qué te interesa?").font(.largeTitle.bold()).padding(.horizontal)
                            Text("Elige al menos un tema. Podrás cambiarlo después.").foregroundStyle(.secondary).padding(.horizontal)
                            CategoryPicker(selection: $app.preferences.categories)
                        }.padding(.top)
                    }.background(Color(uiColor: .systemGroupedBackground))
                default:
                    introduction(symbol: "bell.badge.fill", title: "Lo importante,\na tiempo.", subtitle: "Te avisaremos cuando ocurra algo importante relacionado con tus intereses.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text("Paso \(step + 1) de 4").font(.caption).foregroundStyle(.secondary)
                    Button {
                        if step < 3 { step += 1 }
                        else {
                            requesting = true
                            Task {
                                app.preferences.notificationsEnabled = await app.notifications.requestPermission()
                                finish()
                                requesting = false
                            }
                        }
                    } label: {
                        HStack {
                            if requesting { ProgressView().tint(.white) }
                            Text(step == 0 ? "Comenzar" : step == 3 ? "Activar notificaciones" : "Continuar").fontWeight(.semibold)
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                        .disabled(requesting || (step == 2 && app.preferences.categories.isEmpty))
                    if step == 3 {
                        Button("Ahora no") { app.preferences.notificationsEnabled = false; finish() }.disabled(requesting)
                    }
                }.padding().background(.regularMaterial)
            }
            .toolbar {
                if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("Atrás") { step -= 1 }.disabled(requesting) } }
            }
        }
    }
    private func finish() {
        app.preferences.notificationCategories = app.preferences.categories
        app.preferences.onboardingCompleted = true
    }
    private func introduction(symbol: String, title: String, subtitle: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: symbol).font(.system(size: 72)).foregroundStyle(.indigo).accessibilityHidden(true)
                Text(title).font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
                Label("Tu selección, siempre a tu manera", systemImage: "slider.horizontal.3").font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(28).padding(.top, 48)
        }
    }
}
```

## MyNews/Views/Saved/SavedView.swift

```swift
import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        NavigationStack {
            ScrollView {
                if app.saved.isEmpty {
                    ContentUnavailableView("Tu biblioteca empieza aquí", systemImage: "bookmark", description: Text("Guarda una noticia desde su detalle para leer el resumen después, incluso sin conexión."))
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(app.saved) { article in
                            NavigationLink { ArticleDetailView(article: article) } label: { ArticleCard(article: article) }
                                .buttonStyle(.plain)
                                .contextMenu { Button("Quitar de guardados", role: .destructive) { app.toggleSaved(article) } }
                        }
                    }.padding()
                }
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Guardados")
        }
    }
}
```

## MyNews/Views/Settings/SettingsView.swift

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Personaliza tu lectura") {
                    NavigationLink {
                        CountryPicker(selection: $app.preferences.country)
                    } label: { LabeledContent("País", value: Country(id: app.preferences.country).name) }
                    NavigationLink {
                        ScrollView {
                            Text("Mantén al menos un tema seleccionado.").font(.subheadline).foregroundStyle(.secondary).padding(.top)
                            CategoryPicker(selection: $app.preferences.categories, minimumOne: true)
                        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Temas favoritos")
                    } label: { LabeledContent("Temas favoritos", value: "\(app.preferences.categories.count)") }
                    Picker("Apariencia", selection: $app.preferences.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section { NavigationLink("Notificaciones") { NotificationSettingsView(service: app.notifications) } }
                Section("Acerca de MyNews") {
                    LabeledContent("Fuente de datos", value: app.isDemo ? "Ejemplo" : "Backend conectado")
                    Text(app.isDemo ? "Las noticias son ficticias. Las imágenes de ejemplo requieren internet." : "Los titulares y resúmenes se atribuyen a su fuente original.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Los resúmenes guardados están disponibles sin conexión. Las imágenes y los artículos completos pueden necesitar internet.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Borrar preferencias", role: .destructive) { confirmReset = true }
                } footer: { Text("Reinicia el onboarding y cancela los avisos locales. Conserva tus noticias guardadas.") }
            }.navigationTitle("Configuración")
                .confirmationDialog("¿Borrar tus preferencias?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Borrar preferencias", role: .destructive) { app.resetPreferences() }
                    Button("Cancelar", role: .cancel) {}
                }
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var service: NotificationService
    @State private var requesting = false
    var body: some View {
        Form {
            Section {
                Toggle("Recibir notificaciones", isOn: Binding(get: { app.preferences.notificationsEnabled }, set: { value in
                    if !value { app.preferences.notificationsEnabled = false }
                    else {
                        requesting = true
                        Task {
                            app.preferences.notificationsEnabled = await service.requestPermission()
                            requesting = false
                        }
                    }
                })).disabled(requesting)
                if requesting { ProgressView("Solicitando permiso…") }
                if service.status == .denied {
                    Text("El permiso está desactivado en iOS.").foregroundStyle(.secondary)
                    Button("Abrir ajustes de iOS") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            } footer: { Text("Para avisos de noticias: máximo 3 al día, al menos una hora entre avisos y sin repetir IDs durante 30 días.") }
            Section("Categorías que pueden avisarte") {
                ForEach(NewsCategory.allCases) { category in
                    Toggle(category.title, isOn: Binding(get: { app.preferences.notificationCategories.contains(category) }, set: { selected in
                        if selected { app.preferences.notificationCategories.insert(category) }
                        else { app.preferences.notificationCategories.remove(category) }
                    }))
                }
            }
            Section {
                Button("Enviar notificación local de prueba") { Task { await service.test(preferences: app.preferences) } }
                Text("La prueba aparece en 5 segundos. Los avisos automáticos locales se revisan al actualizar Home con noticias reales. Para avisos con la app cerrada hay que configurar el backend push.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Notificaciones")
            .task { await service.refreshStatus() }
            .alert("Notificaciones", isPresented: Binding(get: { service.message != nil }, set: { if !$0 { service.message = nil } })) {
                Button("Aceptar") { service.message = nil }
            } message: { Text(service.message ?? "") }
    }
}
```

## MyNewsTests/FeedTests.swift

```swift
import XCTest
@testable import MyNews

final class FeedTests: XCTestCase {
    private func article(_ id: String, country: String? = "CR", category: NewsCategory = .technology,
                         date: Date = Date(), url: String? = nil) -> NewsArticle {
        NewsArticle(id: id, title: id, description: "Resumen", imageURL: nil,
                    articleURL: URL(string: url ?? "https://example.com/\(id)")!, source: "Test",
                    publishedAt: date, category: category, country: country, isBreakingNews: false)
    }
    func testFiltersCountryAndInterests() {
        let result = FeedRanker.personalize([
            article("local"), article("global", country: nil), article("foreign", country: "MX"),
            article("sports", category: .sports)
        ], country: "CR", categories: [.technology])
        XCTAssertEqual(Set(result.map(\.id)), ["local", "global"])
    }
    func testDuplicateURLIgnoresTrackingAndFragment() {
        let result = FeedRanker.unique([
            article("a", url: "https://example.com/story?utm_source=one"),
            article("b", url: "https://example.com/story?fbclid=two#heading")
        ])
        XCTAssertEqual(result.count, 1)
    }
    func testPreviousDayLocalDoesNotOutrankNewInternational() {
        let now = Date()
        let result = FeedRanker.personalize([
            article("old", date: now.addingTimeInterval(-86400 * 2)), article("new", country: nil, date: now)
        ], country: "CR", categories: [.technology])
        XCTAssertEqual(result.first?.id, "new")
    }
    func testUnsafeArticleIsExcluded() {
        XCTAssertTrue(FeedRanker.unique([article("bad", url: "javascript:alert(1)")]).isEmpty)
    }
    func testArticleRoundTrip() throws {
        let original = article("roundtrip")
        XCTAssertEqual(try JSONDecoder().decode(NewsArticle.self, from: JSONEncoder().encode(original)), original)
    }
}
```

## MyNewsTests/NetworkingTests.swift

```swift
import XCTest
@testable import MyNews

private class FixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body = """
        {"articles":[{"id":"fixture","title":"Ciencia","description":"Resumen","imageURL":null,
        "articleURL":"https://example.com/story","source":"Fuente","publishedAt":"2026-09-15T10:00:00Z",
        "category":"science","country":"CR","isBreakingNews":false}]}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class UnauthorizedProtocol: FixtureProtocol {
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class NetworkingTests: XCTestCase {
    func testRealServiceDecodesBackendContract() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = RealNewsService(baseURL: URL(string: "https://backend.example.com")!, client: HTTPClient(session: session))
        let articles = try await service.fetchTopHeadlines(country: "CR", categories: ["science"])
        XCTAssertEqual(articles.first?.country, "CR")
        XCTAssertEqual(articles.first?.category, .science)
        XCTAssertNil(articles.first?.imageURL)
    }
    func testUnauthorizedMapsToInvalidKey() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            let _: [String: String] = try await HTTPClient(session: session).get([String: String].self, url: URL(string: "https://example.com")!)
            XCTFail("Expected authentication error")
        } catch NewsError.invalidKey { /* expected */ }
    }
    func testHTTPBackendIsRejected() async throws {
        do {
            let _: [String: String] = try await HTTPClient().get([String: String].self, url: URL(string: "http://example.com")!)
            XCTFail("Expected HTTPS enforcement")
        } catch NewsError.configuration { /* expected */ }
    }
}
```

## MyNewsTests/NotificationPolicyTests.swift

```swift
import XCTest
@testable import MyNews

final class NotificationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var preferences: UserPreferences {
        var value = UserPreferences()
        value.notificationsEnabled = true
        value.notificationCategories = [.sports]
        return value
    }
    private func story(_ id: String = "a", category: NewsCategory = .sports, country: String = "CR", breaking: Bool = true) -> NewsArticle {
        NewsArticle(id: id, title: "Test", description: "Test", imageURL: nil, articleURL: URL(string: "https://example.com/\(id)")!,
                    source: "Test", publishedAt: now.addingTimeInterval(-60), category: category, country: country, isBreakingNews: breaking)
    }
    func testEligibleBreakingStory() {
        XCTAssertNotNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: [:], lastNotification: .distantPast, now: now))
    }
    func testDuplicateAndCooldownAreSuppressed() {
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: ["a": now], lastNotification: .distantPast, now: now))
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: [:], lastNotification: now.addingTimeInterval(-100), now: now))
    }
    func testDailyLimit() {
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences,
            history: ["x": now, "y": now, "z": now], lastNotification: .distantPast, now: now))
    }
    func testDisabledWrongCountryAndNonBreakingDoNotNotify() {
        for article in [story(category: .science), story(country: "MX"), story(breaking: false)] {
            XCTAssertNil(NotificationPolicy.candidate(in: [article], preferences: preferences, history: [:], lastNotification: .distantPast, now: now))
        }
        var disabled = preferences
        disabled.notificationsEnabled = false
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: disabled, history: [:], lastNotification: .distantPast, now: now))
    }
}
```

## MyNewsTests/StorageAndLoadingTests.swift

```swift
import XCTest
@testable import MyNews

@MainActor
final class StorageAndLoadingTests: XCTestCase {
    func testPreferencesPersistAndResetPreservesSavedArticles() async throws {
        let suite = "mynews-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        let state = AppState(store: store)
        state.preferences.country = "MX"
        state.preferences.categories = [.science]
        let articles = try await MockNewsService().fetchTopHeadlines(country: "MX", categories: ["science"])
        state.toggleSaved(try XCTUnwrap(articles.first))
        let restored = AppState(store: store)
        XCTAssertEqual(restored.preferences.country, "MX")
        XCTAssertEqual(restored.saved.count, 1)
        restored.resetPreferences()
        XCTAssertFalse(restored.preferences.onboardingCompleted)
        XCTAssertEqual(restored.saved.count, 1)
    }

    func testOfflineCacheIsScopedToExactRequest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = NewsCache(directory: directory)
        let articles = try await MockNewsService().fetchTopHeadlines(country: "CR", categories: ["science"])
        await cache.write(articles, key: "CR-science")
        let model = NewsListViewModel()
        await model.load(key: "CR-science", cache: cache) { throw NewsError.offline }
        XCTAssertFalse(model.articles.isEmpty)
        XCTAssertNotNil(model.cacheDate)
        await model.load(key: "MX-science", cache: cache) { throw NewsError.offline }
        XCTAssertTrue(model.articles.isEmpty)
        XCTAssertNil(model.cacheDate)
    }

    func testOlderRequestCannotOverwriteNewerResult() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = NewsCache(directory: directory)
        let model = NewsListViewModel()
        let old = Task {
            await model.load(key: "old", cache: cache) {
                try await Task.sleep(for: .milliseconds(100))
                throw NewsError.offline
            }
        }
        try await Task.sleep(for: .milliseconds(20))
        await model.load(key: "new", cache: cache) { [] }
        await old.value
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.loading)
    }
}
```
