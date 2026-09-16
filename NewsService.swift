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
