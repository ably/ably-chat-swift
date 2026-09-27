@testable import AblyChat
import AblyPubSubDevice

final class MockChannels: InternalRealtimeChannelsProtocol {
    private let channels: [MockRealtimeChannel]
    private(set) var getArguments: [(name: String, options: RealtimeChannelOptions)] = []
    private(set) var releaseArguments: [String] = []

    init(channels: [MockRealtimeChannel]) {
        self.channels = channels
    }

    func get(_ name: String, options: RealtimeChannelOptions) -> MockRealtimeChannel {
        getArguments.append((name: name, options: options))

        guard let channel = (channels.first { $0.name == name }) else {
            fatalError("There is no mock channel with name \(name)")
        }

        return channel
    }

    func release(_ name: String) {
        releaseArguments.append(name)
    }
}
