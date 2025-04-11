import Ably
@testable import AblyChat
import Foundation

/// A mock implementation of `InternalRealtimeClientProtocol`. We’ll figure out how to do mocking in tests properly in https://github.com/ably-labs/ably-chat-swift/issues/5.
final class MockRealtime: InternalRealtimeClientProtocol {
    let callRecorder = MockMethodCallRecorder()

    let connection: MockConnection
    let channels: MockChannels
    let paginatedCallback: (@Sendable () throws(ARTErrorInfo) -> ARTHTTPPaginatedResponse)?
    let createWrapperSDKProxyReturnValue: MockSuppliedRealtime?

    private(set) var requestArguments: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?)] = []
    private(set) var createWrapperSDKProxyOptionsArgument: ARTWrapperSDKProxyOptions?

    var clientId: String? {
        "mockClientId"
    }

    init(
        channels: MockChannels = .init(channels: []),
        connection: MockConnection = .init(),
        paginatedCallback: (@Sendable () throws(ARTErrorInfo) -> ARTHTTPPaginatedResponse)? = nil,
        createWrapperSDKProxyReturnValue: MockSuppliedRealtime? = nil
    ) {
        self.channels = channels
        self.paginatedCallback = paginatedCallback
        self.connection = connection
        self.createWrapperSDKProxyReturnValue = createWrapperSDKProxyReturnValue
    }

    func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(InternalError) -> ARTHTTPPaginatedResponse {
        requestArguments.append((method: method, path: path, params: params, body: body, headers: headers))
        guard let paginatedCallback else {
            fatalError("Paginated callback not set")
        }
        do {
            callRecorder.addRecord(
                signature: "request(_:path:params:body:headers:)",
                arguments: ["method": method, "path": path, "params": params, "body": body == nil ? [:] : body as? [String: Any], "headers": headers]
            )
            return try paginatedCallback()
        } catch {
            throw error.toInternalError()
        }
    }

    func createWrapperSDKProxy(with options: ARTWrapperSDKProxyOptions) -> some RealtimeClientProtocol {
        guard let createWrapperSDKProxyReturnValue else {
            fatalError("createWrapperSDKProxyReturnValue must be set in order to call createWrapperSDKProxy(with:)")
        }

        createWrapperSDKProxyOptionsArgument = options

        return createWrapperSDKProxyReturnValue
    }
}
