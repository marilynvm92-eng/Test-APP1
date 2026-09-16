import XCTest
@testable import MyNews

private class FixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body = """
        {"articles":[{"id":"fixture","title":"Ciencia","description":"Resumen","imageURL":null,
        "articleURL":"https://example.com/story","source":"Fuente","publishedAt":"2026-09-15T10:00:00Z",
        "category":"science","country":"CR","isBreakingNews":false}]}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class UnauthorizedProtocol: FixtureProtocol {
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class NetworkingTests: XCTestCase {
    func testRealServiceDecodesBackendContract() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = RealNewsService(baseURL: URL(string: "https://backend.example.com")!, client: HTTPClient(session: session))
        let articles = try await service.fetchTopHeadlines(country: "CR", categories: ["science"])
        XCTAssertEqual(articles.first?.country, "CR")
        XCTAssertEqual(articles.first?.category, .science)
        XCTAssertNil(articles.first?.imageURL)
    }
    func testUnauthorizedMapsToInvalidKey() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            let _: [String: String] = try await HTTPClient(session: session).get([String: String].self, url: URL(string: "https://example.com")!)
            XCTFail("Expected authentication error")
        } catch NewsError.invalidKey { /* expected */ }
    }
    func testHTTPBackendIsRejected() async throws {
        do {
            let _: [String: String] = try await HTTPClient().get([String: String].self, url: URL(string: "http://example.com")!)
            XCTFail("Expected HTTPS enforcement")
        } catch NewsError.configuration { /* expected */ }
    }
}
