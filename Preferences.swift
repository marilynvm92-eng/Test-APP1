import Foundation

enum NewsCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case breaking, sports, technology, science, economy, business
    case entertainment, health, politics, world, culture, gaming
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breaking: "Última hora"
        case .sports: "Deportes"
        case .technology: "Tecnología"
        case .science: "Ciencia"
        case .economy: "Economía"
        case .business: "Negocios"
        case .entertainment: "Entretenimiento"
        case .health: "Salud"
        case .politics: "Política"
        case .world: "Mundo"
        case .culture: "Cultura"
        case .gaming: "Videojuegos"
        }
    }
    var symbol: String {
        switch self {
        case .breaking: "bolt.fill"
        case .sports: "sportscourt.fill"
        case .technology: "desktopcomputer"
        case .science: "atom"
        case .economy: "chart.line.uptrend.xyaxis"
        case .business: "briefcase.fill"
        case .entertainment: "film.fill"
        case .health: "heart.fill"
        case .politics: "building.columns.fill"
        case .world: "globe.americas.fill"
        case .culture: "theatermasks.fill"
        case .gaming: "gamecontroller.fill"
        }
    }
}

struct Country: Identifiable, Hashable, Sendable {
    let id: String
    var name: String { Locale(identifier: "es").localizedString(forRegionCode: id) ?? id }
    var flag: String {
        String(String.UnicodeScalarView(id.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }
    static let all: [Country] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.unicodeScalars.allSatisfy { (65...90).contains($0.value) } }
        .map { Country(id: $0) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "Sistema"; case .light: "Claro"; case .dark: "Oscuro" }
    }
}

struct UserPreferences: Codable, Equatable {
    var country = "CR"
    var categories: Set<NewsCategory> = []
    var notificationCategories: Set<NewsCategory> = []
    var notificationsEnabled = false
    var appearance: Appearance = .system
    var onboardingCompleted = false
}
