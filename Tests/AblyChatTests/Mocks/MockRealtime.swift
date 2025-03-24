import Ably
@testable import AblyChat
import Foundation

/// A mock implementation of `InternalRealtimeClientProtocol`. We’ll figure out how to do mocking in tests properly in https://github.com/ably-labs/ably-chat-swift/issues/5.
final class MockRealtime: NSObject, InternalRealtimeClientProtocol, @unchecked Sendable {
    let connection: MockConnection
    let channels: MockChannels
    let paginatedCallback: (@Sendable () throws(ARTErrorInfo) -> ARTHTTPPaginatedResponse)?
    let createWrapperSDKProxyReturnValue: MockSuppliedRealtime?

    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _requestArguments: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?)] = []
    /// Access must be synchronized via ``mutex``.
    private(set) var _createWrapperSDKProxyOptionsArgument: ARTWrapperSDKProxyOptions?

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
        mutex.withLock {
            _requestArguments.append((method: method, path: path, params: params, body: body, headers: headers))
        }
        guard let paginatedCallback else {
            fatalError("Paginated callback not set")
        }
        do {
            return try paginatedCallback()
        } catch {
            throw error.toInternalError()
        }
    }

    var requestArguments: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?)] {
        mutex.withLock {
            _requestArguments
        }
    }

    func createWrapperSDKProxy(with options: ARTWrapperSDKProxyOptions) -> some RealtimeClientProtocol {
        guard let createWrapperSDKProxyReturnValue else {
            fatalError("createWrapperSDKProxyReturnValue must be set in order to call createWrapperSDKProxy(with:)")
        }

        mutex.lock()
        _createWrapperSDKProxyOptionsArgument = options
        mutex.unlock()

        return createWrapperSDKProxyReturnValue
    }

    var createWrapperSDKProxyOptionsArgument: ARTWrapperSDKProxyOptions? {
        let result: ARTWrapperSDKProxyOptions?
        mutex.lock()
        result = _createWrapperSDKProxyOptionsArgument
        mutex.unlock()
        return result
    }
}
