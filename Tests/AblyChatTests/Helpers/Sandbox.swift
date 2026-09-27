import CryptoKit
import Foundation

/// Provides the ``createAPIKey()`` function to create an API key for the Ably sandbox environment.
enum Sandbox {
    // MARK: - JWT

    /// Creates a signed Ably JWT (HS256) containing the given `userClaim` under the `ably.room.<roomName>` key.
    ///
    /// The returned string can be passed to `ARTTokenDetails(token:)` and used via `authCallback`.
    static func createJWT(
        apiKey: String,
        clientID: String,
        roomName: String,
        userClaim: String,
        ttl: TimeInterval = 3600,
    ) -> String {
        let parts = apiKey.split(separator: ":", maxSplits: 1)
        let keyName = String(parts[0])
        let keySecret = String(parts[1])

        let header: [String: Any] = [
            "typ": "JWT",
            "alg": "HS256",
            "kid": keyName,
        ]

        let now = Date()
        let payload: [String: Any] = [
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(now.timeIntervalSince1970 + ttl),
            "x-ably-clientId": clientID,
            "x-ably-capability": "{\"*\":[\"*\"]}",
            "ably.room.\(roomName)": userClaim,
        ]

        let headerData = try! JSONSerialization.data(withJSONObject: header) // swiftlint:disable:this force_try
        let payloadData = try! JSONSerialization.data(withJSONObject: payload) // swiftlint:disable:this force_try

        let headerB64 = base64URLEncode(headerData)
        let payloadB64 = base64URLEncode(payloadData)

        let signingInput = "\(headerB64).\(payloadB64)"
        let key = SymmetricKey(data: Data(keySecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let signatureB64 = base64URLEncode(Data(signature))

        return "\(headerB64).\(payloadB64).\(signatureB64)"
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Sandbox API key

    private struct TestApp: Codable {
        var keys: [Key]

        struct Key: Codable {
            var keyStr: String
        }
    }

    enum Error: Swift.Error {
        case badResponseStatus(Int)
    }

    private static func loadAppCreationRequestBody() async throws -> Data {
        let testAppSetupFileURL = Bundle.module.url(
            forResource: "test-app-setup",
            withExtension: "json",
            subdirectory: "ably-common/test-resources",
        )!

        let (data, _) = try await URLSession.shared.data(for: .init(url: testAppSetupFileURL))
        // swiftlint:disable:next force_cast
        let dictionary = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return try JSONSerialization.data(withJSONObject: dictionary["post_apps"]!)
    }

    static func createAPIKey() async throws -> String {
        var request = URLRequest(url: .init(string: "https://sandbox-rest.ably.io/apps")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try await loadAppCreationRequestBody()

        let (data, response) = try await URLSession.shared.data(for: request)

        // swiftlint:disable:next force_cast
        let statusCode = (response as! HTTPURLResponse).statusCode

        guard (200 ..< 300).contains(statusCode) else {
            throw Error.badResponseStatus(statusCode)
        }

        let testApp = try JSONDecoder().decode(TestApp.self, from: data)

        // From JS chat repo at 7985ab7 — "The key we need to use is the one at index 5, which gives enough permissions to interact with Chat and Channels"
        return testApp.keys[5].keyStr
    }
}
