import XCTest
@testable import MyNews

final class NotificationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var preferences: UserPreferences {
        var value = UserPreferences()
        value.notificationsEnabled = true
        value.notificationCategories = [.sports]
        return value
    }
    private func story(_ id: String = "a", category: NewsCategory = .sports, country: String = "CR", breaking: Bool = true) -> NewsArticle {
        NewsArticle(id: id, title: "Test", description: "Test", imageURL: nil, articleURL: URL(string: "https://example.com/\(id)")!,
                    source: "Test", publishedAt: now.addingTimeInterval(-60), category: category, country: country, isBreakingNews: breaking)
    }
    func testEligibleBreakingStory() {
        XCTAssertNotNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: [:], lastNotification: .distantPast, now: now))
    }
    func testDuplicateAndCooldownAreSuppressed() {
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: ["a": now], lastNotification: .distantPast, now: now))
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences, history: [:], lastNotification: now.addingTimeInterval(-100), now: now))
    }
    func testDailyLimit() {
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: preferences,
            history: ["x": now, "y": now, "z": now], lastNotification: .distantPast, now: now))
    }
    func testDisabledWrongCountryAndNonBreakingDoNotNotify() {
        for article in [story(category: .science), story(country: "MX"), story(breaking: false)] {
            XCTAssertNil(NotificationPolicy.candidate(in: [article], preferences: preferences, history: [:], lastNotification: .distantPast, now: now))
        }
        var disabled = preferences
        disabled.notificationsEnabled = false
        XCTAssertNil(NotificationPolicy.candidate(in: [story()], preferences: disabled, history: [:], lastNotification: .distantPast, now: now))
    }
}
