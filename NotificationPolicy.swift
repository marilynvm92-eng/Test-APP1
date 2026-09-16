import Foundation

enum NotificationPolicy {
    static func candidate(in articles: [NewsArticle], preferences: UserPreferences,
                          history: [String: Date], lastNotification: Date,
                          now: Date = Date(), calendar: Calendar = .current) -> NewsArticle? {
        guard preferences.notificationsEnabled,
              now.timeIntervalSince(lastNotification) >= 3600,
              history.values.filter({ calendar.isDate($0, inSameDayAs: now) }).count < 3 else { return nil }
        return articles.filter {
            $0.isBreakingNews && preferences.notificationCategories.contains($0.category) &&
            ($0.country == nil || $0.country?.uppercased() == preferences.country.uppercased()) &&
            now.timeIntervalSince($0.publishedAt) >= 0 && now.timeIntervalSince($0.publishedAt) < 6 * 3600 &&
            history[$0.id] == nil
        }.sorted { $0.publishedAt > $1.publishedAt }.first
    }
}
