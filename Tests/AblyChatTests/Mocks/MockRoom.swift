import Ably
@testable import AblyChat

class MockRoom: InternalRoom {
    let options: RoomOptions
    private(set) var releaseCallCount = 0
    let releaseImplementation: (@Sendable () async -> Void)?

    init(options: RoomOptions, releaseImplementation: (@Sendable () async -> Void)? = nil) {
        self.options = options
        self.releaseImplementation = releaseImplementation
        _releaseCallsAsyncSequence = AsyncStream<Void>.makeStream()
    }

    var name: String {
        fatalError("Not implemented")
    }

    var messages: DefaultMessages {
        fatalError("Not implemented")
    }

    var presence: DefaultPresence {
        fatalError("Not implemented")
    }

    var reactions: DefaultRoomReactions {
        fatalError("Not implemented")
    }

    var typing: DefaultTyping {
        fatalError("Not implemented")
    }

    var occupancy: DefaultOccupancy {
        fatalError("Not implemented")
    }

    var status: AblyChat.RoomStatus {
        fatalError("Not implemented")
    }

    func attach() async throws(ARTErrorInfo) {
        fatalError("Not implemented")
    }

    func detach() async throws(ARTErrorInfo) {
        fatalError("Not implemented")
    }

    func release() async {
        releaseCallCount += 1
        _releaseCallsAsyncSequence.continuation.yield(())
        guard let releaseImplementation else {
            fatalError("releaseImplementation must be set before calling `release`")
        }
        await releaseImplementation()
    }

    /// Emits an element each time ``release()`` is called.
    var releaseCallsAsyncSequence: AsyncStream<Void> {
        _releaseCallsAsyncSequence.stream
    }

    private let _releaseCallsAsyncSequence: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation)

    @discardableResult
    func onStatusChange(_: @escaping @MainActor (RoomStatusChange) -> Void) -> DefaultStatusSubscription {
        fatalError("Not implemented")
    }

    @discardableResult
    func onDiscontinuity(_: @escaping @MainActor (ARTErrorInfo) -> Void) -> DefaultStatusSubscription {
        fatalError("Not implemented")
    }

    var channel: MockAblyCocoaRealtime.Channel {
        fatalError("Not implemented")
    }
}
