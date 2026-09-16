import Foundation

@MainActor
final class LocalStore {
    private let defaults: UserDefaults
    private let prefix = "mynews.v1."
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: prefix + key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: prefix + key)
    }
    func remove(_ key: String) { defaults.removeObject(forKey: prefix + key) }
}
