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
