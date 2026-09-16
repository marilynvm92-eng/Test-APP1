import Foundation

enum NewsError: LocalizedError {
    case offline, server(Int), invalidResponse, decoding, invalidKey, rateLimited, configuration
    var errorDescription: String? {
        switch self {
        case .offline: "No hay conexión a internet."
        case .server: "El servidor no está disponible. Inténtalo más tarde."
        case .invalidResponse: "El servidor devolvió una respuesta inválida."
        case .decoding: "No pudimos interpretar las noticias recibidas."
        case .invalidKey: "El servicio no está autorizado. Revisa la configuración del servidor."
        case .rateLimited: "Se alcanzó el límite del servicio. Inténtalo más tarde."
        case .configuration: "Configura una dirección HTTPS válida para el backend."
        }
    }
}
