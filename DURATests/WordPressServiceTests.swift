import Testing
import Foundation
@testable import DURA

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helper

private func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private let testConfig = WordPressConfig(
    siteURL: "https://example.com",
    username: "admin",
    appPassword: "xxxx xxxx xxxx"
)

// MARK: - WordPress Service Tests

@Suite("WordPressService")
struct WordPressServiceTests {

    @Test("Creates new post with POST request")
    func createNewPost() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path.hasSuffix("/wp/v2/posts") == true)

            let responseJSON: [String: Any] = ["id": 42, "status": "publish"]
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        let meta = DraftMetadata()
        let result = try await service.publishPost(
            title: "Test Post",
            markdown: "Hello world",
            metadata: meta,
            config: testConfig,
            asDraft: false
        )

        #expect(result.wordpressPostId == 42)
        #expect(result.wordpressStatus == .published)
        #expect(result.lastPublishedAt != nil)
    }

    @Test("Updates existing post with PUT request")
    func updateExistingPost() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.path.contains("/wp/v2/posts/99") == true)

            let responseJSON: [String: Any] = ["id": 99, "status": "publish"]
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        var meta = DraftMetadata()
        meta.wordpressPostId = 99

        let result = try await service.publishPost(
            title: "Updated Post",
            markdown: "Updated content",
            metadata: meta,
            config: testConfig,
            asDraft: false
        )

        #expect(result.wordpressPostId == 99)
        #expect(result.wordpressStatus == .published)
    }

    @Test("Draft flag sets status to draft")
    func publishAsDraft() async throws {
        MockURLProtocol.requestHandler = { request in
            // Verify the body contains "draft" status
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                #expect(json["status"] as? String == "draft")
            }

            let responseJSON: [String: Any] = ["id": 50, "status": "draft"]
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        let result = try await service.publishPost(
            title: "Draft Post",
            markdown: "Content",
            metadata: DraftMetadata(),
            config: testConfig,
            asDraft: true
        )

        #expect(result.wordpressStatus == .draft)
    }

    @Test("Sends correct auth header")
    func authHeader() async throws {
        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
            #expect(authHeader.hasPrefix("Basic "))

            // Decode and verify credentials
            let base64 = String(authHeader.dropFirst(6))
            if let decoded = Data(base64Encoded: base64).flatMap({ String(data: $0, encoding: .utf8) }) {
                #expect(decoded == "admin:xxxx xxxx xxxx")
            }

            let responseJSON: [String: Any] = ["id": 1, "status": "publish"]
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        _ = try await service.publishPost(
            title: "Test",
            markdown: "Content",
            metadata: DraftMetadata(),
            config: testConfig,
            asDraft: false
        )
    }

    @Test("Validate connection succeeds on 200")
    func validateConnectionSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.contains("/wp/v2/users/me") == true)

            let responseJSON: [String: Any] = ["id": 1, "name": "admin"]
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        try await service.validateConnection(config: testConfig)
    }

    @Test("Throws on 401 authentication failure")
    func authenticationFailure() async {
        MockURLProtocol.requestHandler = { request in
            let data = "{}".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let service = WordPressService(session: makeTestSession())
        do {
            _ = try await service.publishPost(
                title: "Test",
                markdown: "Content",
                metadata: DraftMetadata(),
                config: testConfig,
                asDraft: false
            )
            Issue.record("Expected WordPressError.authenticationFailed")
        } catch let error as WordPressError {
            if case .authenticationFailed = error {
                // Expected
            } else {
                Issue.record("Expected authenticationFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
