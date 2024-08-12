import Ably

/// A mock implementation of `ARTRealtimeProtocol`. It only exists so that we can construct an instance of `DefaultChatClient` without needing to create a proper `ARTRealtime` instance (which we can’t yet do because we don’t have a method for inserting an API key into the example app). TODO remove this once we start building the example app
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
