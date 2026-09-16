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
