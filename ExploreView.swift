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
