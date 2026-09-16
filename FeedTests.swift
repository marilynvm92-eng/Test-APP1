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
