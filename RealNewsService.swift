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
