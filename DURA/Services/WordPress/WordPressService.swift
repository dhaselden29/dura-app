import Foundation

// MARK: - Configuration

struct WordPressConfig: Codable, Sendable {
    var siteURL: String
    var username: String
    var appPassword: String

    /// Base URL for the WP REST API, e.g. "https://example.com/wp-json".
    var apiBaseURL: String {
        let trimmed = siteURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(trimmed)/wp-json"
    }
}

// MARK: - Errors

enum WordPressError: LocalizedError, Sendable {
    case notConfigured
    case invalidURL
    case authenticationFailed
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "WordPress credentials are not configured."
        case .invalidURL:
            "The WordPress site URL is invalid."
        case .authenticationFailed:
            "WordPress authentication failed. Check your username and application password."
        case .networkError(let message):
            "Network error: \(message)"
        case .apiError(let code, let message):
            "WordPress API error (\(code)): \(message)"
        }
    }
}

// MARK: - Service

actor WordPressService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Publish / Update Post

    /// Creates or updates a WordPress post.
    /// Returns updated `DraftMetadata` with the WP post ID and status.
    func publishPost(
        title: String,
        markdown: String,
        metadata: DraftMetadata,
        config: WordPressConfig,
        asDraft: Bool = false,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> DraftMetadata {
        progress?(0.1)

        let htmlBody = HTMLExportProvider.renderHTML(from: markdown)

        progress?(0.3)

        let wpStatus = asDraft ? "draft" : "publish"

        var body: [String: Any] = [
            "title": title,
            "content": htmlBody,
            "status": wpStatus,
        ]

        if let slug = metadata.slug {
            body["slug"] = slug
        }
        if let excerpt = metadata.excerpt {
            body["excerpt"] = excerpt
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        let request: URLRequest
        if let existingPostId = metadata.wordpressPostId {
            // Update existing post
            request = try buildRequest(
                path: "/wp/v2/posts/\(existingPostId)",
                method: "PUT",
                body: jsonData,
                config: config
            )
        } else {
            // Create new post
            request = try buildRequest(
                path: "/wp/v2/posts",
                method: "POST",
                body: jsonData,
                config: config
            )
        }

        progress?(0.5)

        let (data, response) = try await session.data(for: request)

        progress?(0.8)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw WordPressError.authenticationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw WordPressError.apiError(httpResponse.statusCode, message)
        }

        // Parse response to get post ID
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let postId = json["id"] as? Int else {
            throw WordPressError.apiError(httpResponse.statusCode, "Could not parse post ID from response")
        }

        progress?(1.0)

        var updatedMeta = metadata
        updatedMeta.wordpressPostId = postId
        updatedMeta.wordpressStatus = asDraft ? .draft : .published
        updatedMeta.lastPublishedAt = Date()
        return updatedMeta
    }

    // MARK: - Validate Connection

    /// Tests authentication by calling `GET /wp/v2/users/me`.
    func validateConnection(config: WordPressConfig) async throws {
        let request = try buildRequest(
            path: "/wp/v2/users/me",
            method: "GET",
            config: config
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw WordPressError.authenticationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw WordPressError.apiError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Helpers

    private func buildRequest(
        path: String,
        method: String,
        body: Data? = nil,
        config: WordPressConfig
    ) throws -> URLRequest {
        let urlString = config.apiBaseURL + path
        guard let url = URL(string: urlString) else {
            throw WordPressError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Basic Auth with application password
        let credentials = "\(config.username):\(config.appPassword)"
        guard let credentialData = credentials.data(using: .utf8) else {
            throw WordPressError.authenticationFailed
        }
        let base64 = credentialData.base64EncodedString()
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")

        request.httpBody = body

        return request
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String
    }
}
