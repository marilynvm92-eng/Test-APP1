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
