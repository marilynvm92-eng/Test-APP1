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
