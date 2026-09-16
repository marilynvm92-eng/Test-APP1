import Foundation

struct HTTPClient: Sendable {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func get<T: Decodable & Sendable>(_ type: T.Type, url: URL) async throws -> T {
        guard url.scheme == "https", url.host != nil else { throw NewsError.configuration }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw NewsError.invalidResponse }
            switch response.statusCode {
            case 200...299: break
            case 401, 403: throw NewsError.invalidKey
            case 429: throw NewsError.rateLimited
            default: throw NewsError.server(response.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NewsError.decoding }
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            if [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut].contains(error.code) {
                throw NewsError.offline
            }
            throw NewsError.invalidResponse
        }
    }
}
