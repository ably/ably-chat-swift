@testable import AblyChat

actor MockRoom: InternalRoom {
    let options: RoomOptions
    private(set) var releaseCallCount = 0
    let releaseImplementation: (@Sendable () async -> Void)?

    init(options: RoomOptions, releaseImplementation: (@Sendable () async -> Void)? = nil) {
        self.options = options
        self.releaseImplementation = releaseImplementation
    }

    nonisolated var roomID: String {
        fatalError("Not implemented")
    }

    nonisolated var messages: any Messages {
        fatalError("Not implemented")
    }

    nonisolated var presence: any Presence {
        fatalError("Not implemented")
    }

    nonisolated var reactions: any RoomReactions {
        fatalError("Not implemented")
    }

    nonisolated var typing: any Typing {
        fatalError("Not implemented")
    }

    nonisolated var occupancy: any Occupancy {
        fatalError("Not implemented")
    }

    var status: AblyChat.RoomStatus {
        fatalError("Not implemented")
    }

    func onStatusChange(bufferingPolicy _: BufferingPolicy) async -> Subscription<RoomStatusChange> {
        fatalError("Not implemented")
    }

    func attach() async throws {
        fatalError("Not implemented")
    }

    func detach() async throws {
        fatalError("Not implemented")
    }

    func release() async {
        releaseCallCount += 1
        guard let releaseImplementation else {
            fatalError("releaseImplementation must be set before calling `release`")
        }
        await releaseImplementation()
    }
}