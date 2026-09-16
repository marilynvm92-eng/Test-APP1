import Foundation
import CryptoKit

actor NewsCache {
    struct Entry: Codable, Sendable {
        let articles: [NewsArticle]
        let savedAt: Date
    }
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyNews", isDirectory: true)
    }
    private func file(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }
    func read(_ key: String) -> Entry? {
        guard let data = try? Data(contentsOf: file(key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < 7 * 24 * 3600 else { return nil }
        return entry
    }
    func write(_ articles: [NewsArticle], key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Entry(articles: Array(articles.prefix(100)), savedAt: Date()))
            try data.write(to: file(key), options: .atomic)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            let sorted = files.sorted {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
                ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
            for old in sorted.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
        } catch { /* Cache failure must not hide successfully loaded news. */ }
    }
    func clear() { try? FileManager.default.removeItem(at: directory) }
}
