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
