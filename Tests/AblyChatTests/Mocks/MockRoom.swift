@testable import AblyChat

actor MockRoom: Room {
    let options: RoomOptions

    init(options: RoomOptions) {
        self.options = options
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
}
