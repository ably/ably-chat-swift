import Ably
import Foundation

/// A mock implementation of `ARTRealtimeProtocol`. Copied from the class of the same name in the example app. We’ll figure out how to do mocking in tests properly in https://github.com/ably-labs/ably-chat-swift/issues/5.
class MockRealtime: NSObject, ARTRealtimeProtocol {
    var device: ARTLocalDevice {
        fatalError("Not implemented")
    }

    var clientId: String?

    required init(options _: ARTClientOptions) {}

    required init(key _: String) {}

    required init(token _: String) {}

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
}
