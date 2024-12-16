import Ably
import AblyChat
import Foundation

/// A mock implementation of `ARTRealtimeProtocol`. We’ll figure out how to do mocking in tests properly in https://github.com/ably-labs/ably-chat-swift/issues/5.
final class MockRealtime: NSObject, RealtimeClientProtocol, @unchecked Sendable {
    let connection: MockConnection
    let channels: MockChannels
    let paginatedCallback: (@Sendable () -> (ARTHTTPPaginatedResponse?, ARTErrorInfo?))?

    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _requestArguments: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?, callback: ARTHTTPPaginatedCallback)] = []

    var device: ARTLocalDevice {
        fatalError("Not implemented")
    }

    var clientId: String? {
        "mockClientId"
    }

    init(
        channels: MockChannels = .init(channels: []),
        connection: MockConnection = .init(),
        paginatedCallback: (@Sendable () -> (ARTHTTPPaginatedResponse?, ARTErrorInfo?))? = nil
    ) {
        self.channels = channels
        self.paginatedCallback = paginatedCallback
        self.connection = connection
    }

    required init(options _: ARTClientOptions) {
        channels = .init(channels: [])
        connection = .init()
        paginatedCallback = nil
    }

    required init(key _: String) {
        channels = .init(channels: [])
        connection = .init()
        paginatedCallback = nil
    }

    required init(token _: String) {
        channels = .init(channels: [])
        connection = .init()
        paginatedCallback = nil
    }

    /**
     Creates an instance of MockRealtime.

     This exists to give a convenient way to create an instance, because `init` is marked as unavailable in `ARTRealtimeProtocol`.
     */
    static func create(
        channels: MockChannels = MockChannels(channels: []),
        connection: MockConnection = MockConnection(),
        paginatedCallback: (@Sendable () -> (ARTHTTPPaginatedResponse?, ARTErrorInfo?))? = nil
    ) -> MockRealtime {
        MockRealtime(channels: channels, connection: connection, paginatedCallback: paginatedCallback)
    }

    func time(_: @escaping ARTDateTimeCallback) {
        fatalError("Not implemented")
    }

    func ping(_: @escaping ARTCallback) {
        fatalError("Not implemented")
    }

    func stats(_: @escaping ARTPaginatedStatsCallback) -> Bool {
        fatalError("Not implemented")
    }

    func stats(_: ARTStatsQuery?, callback _: @escaping ARTPaginatedStatsCallback) throws {
        fatalError("Not implemented")
    }

    func connect() {
        fatalError("Not implemented")
    }

    func close() {
        fatalError("Not implemented")
    }

    func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?, callback: @escaping ARTHTTPPaginatedCallback) throws {
        mutex.lock()
        _requestArguments.append((method: method, path: path, params: params, body: body, headers: headers, callback: callback))
        mutex.unlock()
        guard let paginatedCallback else {
            fatalError("Paginated callback not set")
        }
        let (paginatedResponse, error) = paginatedCallback()
        callback(paginatedResponse, error)
    }

    var requestArguments: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?, callback: ARTHTTPPaginatedCallback)] {
        let result: [(method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?, callback: ARTHTTPPaginatedCallback)]
        mutex.lock()
        result = _requestArguments
        mutex.unlock()
        return result
    }
}
