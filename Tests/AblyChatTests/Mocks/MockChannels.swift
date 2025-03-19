import Ably
import AblyChat

final class MockChannels: RealtimeChannelsProtocol, @unchecked Sendable {
    private let channels: [MockRealtimeChannel]
    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _getArguments: [(name: String, options: ARTRealtimeChannelOptions)] = []
    /// Access must be synchronized via ``mutex``.
    private(set) var _releaseArguments: [String] = []

    init(channels: [MockRealtimeChannel]) {
        self.channels = channels
    }

    func get(_ name: String, options: ARTRealtimeChannelOptions) -> MockRealtimeChannel {
        mutex.withLock {
            _getArguments.append((name: name, options: options))
        }

        guard let channel = (channels.first { $0.name == name }) else {
            fatalError("There is no mock channel with name \(name)")
        }

        return channel
    }

    var getArguments: [(name: String, options: ARTRealtimeChannelOptions)] {
        mutex.withLock {
            _getArguments
        }
    }

    func exists(_: String) -> Bool {
        fatalError("Not implemented")
    }

    func release(_: String, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func release(_ name: String) {
        mutex.withLock {
            _releaseArguments.append(name)
        }
    }

    var releaseArguments: [String] {
        mutex.withLock {
            _releaseArguments
        }
    }
}
