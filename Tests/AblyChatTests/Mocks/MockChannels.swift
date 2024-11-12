import Ably
import AblyChat

final class MockChannels: RealtimeChannelsProtocol, @unchecked Sendable {
    private let channels: [MockRealtimeChannel]
    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _releaseArguments: [String] = []

    init(channels: [MockRealtimeChannel]) {
        self.channels = channels
    }

    func get(_ name: String, options _: ARTRealtimeChannelOptions) -> MockRealtimeChannel {
        guard let channel = (channels.first { $0.name == name }) else {
            fatalError("There is no mock channel with name \(name)")
        }

        return channel
    }

    func exists(_: String) -> Bool {
        fatalError("Not implemented")
    }

    func release(_: String, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func release(_ name: String) {
        mutex.lock()
        defer { mutex.unlock() }
        _releaseArguments.append(name)
    }

    var releaseArguments: [String] {
        let result: [String]
        mutex.lock()
        result = _releaseArguments
        mutex.unlock()
        return result
    }
}
