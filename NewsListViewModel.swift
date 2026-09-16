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
