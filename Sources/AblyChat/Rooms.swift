import Ably

public protocol Rooms: AnyObject, Sendable {
    func get(roomID: String, options: RoomOptions) async throws -> any Room
    func release(roomID: String) async throws
    var clientOptions: ClientOptions { get }
}

internal actor DefaultRooms<RoomFactory: AblyChat.RoomFactory>: Rooms {
    private nonisolated let realtime: RealtimeClient
    private let chatAPI: ChatAPI

    #if DEBUG
        internal nonisolated var testsOnly_realtime: RealtimeClient {
            realtime
        }
    #endif

    internal nonisolated let clientOptions: ClientOptions

    private let logger: InternalLogger
    private let roomFactory: RoomFactory

    private enum RoomState {
        /// There is no room map entry for this room ID, but a CHA-RC1g release operation is in progress.
        case releaseOperationInProgress(releaseTask: Task<Void, Never>)

        /// There is a room map entry for this room ID.
        case roomMapEntry(RoomMapEntry)
    }

    private enum RoomMapEntry {
        /// The room has been requested, but is awaiting the completion of a CHA-RC1g release operation.
        case requestAwaitingRelease(
            releaseTask: Task<Void, Never>,
            requestedOptions: RoomOptions,
            creationTask: Task<RoomFactory.Room, Error>,
            failCreationTask: @Sendable (Error) -> Void
        )

        /// The room has been created.
        case created(room: RoomFactory.Room)

        var roomOptions: RoomOptions {
            switch self {
            case let .requestAwaitingRelease(_, requestedOptions: options, _, _):
                options
            case let .created(room):
                room.options
            }
        }

        func waitForRoom() async throws -> RoomFactory.Room {
            switch self {
            case let .requestAwaitingRelease(_, _, creationTask: creationTask, _):
                try await creationTask.value
            case let .created(room):
                room
            }
        }
    }

    // TODO: update comment
    /// The set of rooms, keyed by room ID.
    private var roomStates: [String: RoomState] = [:]

    internal init(realtime: RealtimeClient, clientOptions: ClientOptions, logger: InternalLogger, roomFactory: RoomFactory) {
        self.realtime = realtime
        self.clientOptions = clientOptions
        self.logger = logger
        self.roomFactory = roomFactory
        chatAPI = ChatAPI(realtime: realtime)
    }

    #if DEBUG
    internal struct ReleaseOperationWaitEvent {}

    // TODO tidy up documentation

    // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
    /// Supports the ``testsOnly_subscribeToOperationWaitEvents()`` method.
    private var releaseOperationWaitEventSubscriptions: [Subscription<ReleaseOperationWaitEvent>] = []

        /// Returns a subscription which emits an event each time one room lifecycle operation is going to wait for another to complete.
        internal func testsOnly_subscribeToReleaseOperationWaitEvents() -> Subscription<ReleaseOperationWaitEvent> {
            let subscription = Subscription<ReleaseOperationWaitEvent>(bufferingPolicy: .unbounded)
            releaseOperationWaitEventSubscriptions.append(subscription)
            return subscription
        }
    #endif

    internal func get(roomID: String, options: RoomOptions) async throws -> any Room {
        if let existingRoomState = roomStates[roomID] {
            switch existingRoomState {
            // TODO: when testing this, test all cases of RoomMapEntry
            case let .roomMapEntry(existingRoomMapEntry):
                // CHA-RC1f1
                if existingRoomMapEntry.roomOptions != options {
                    throw ARTErrorInfo(
                        chatError: .inconsistentRoomOptions(requested: options, existing: existingRoomMapEntry.roomOptions)
                    )
                }

                // TODO: which of CHA-RC1f1 OR cha-rc1F2 takes priority here? i.e. do we now need to consider whether there's a release in progress? I guess that's what's happening anyway since this waits for something that's waiting for a release

                // CHA-RC1f2
                return try await existingRoomMapEntry.waitForRoom()
            case let .releaseOperationInProgress(releaseTask: releaseTask):
                // TODO: tidy this stuff up
                let (stream, continuation) = AsyncThrowingStream.makeStream(of: Void.self, throwing: Error.self)

                let failCreationTask = { @Sendable (error: Error) in
                    continuation.finish(throwing: error)
                }

                let creationTask = Task {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            try await stream.first { _ in true }
                        }

                        group.addTask {
                            // TODO: how to make this exit if the task is cancelled? the detached is to not propagate cancellation, but that won't make cancellation break us out of this `await`. Hmm
                            await Task.detached {
                                // CHA-RC1f4
                                await releaseTask.value
                            }.value
                        }

                        // This pattern for waiting for the first of multiple tasks is taken from here
                        // https://forums.swift.org/t/accept-the-first-task-to-complete/54386
                        defer { group.cancelAll() }
                        // TODO: how do we guarantee we’ll get the right error?
                        try await group.next()
                    }

                    return try await createRoom(roomID: roomID, options: options)
                }
                roomStates[roomID] = .roomMapEntry(
                    .requestAwaitingRelease(
                        releaseTask: releaseTask,
                        requestedOptions: options,
                        creationTask: creationTask,
                        failCreationTask: failCreationTask
                    )
                )
                return try await creationTask.value
            }
        }

        // CHA-RC1f3
        return try await createRoom(roomID: roomID, options: options)
    }

    private func waitForReleaseTask(_ releaseTask: Task<Void, Never>) async {
        #if DEBUG
                    let operationWaitEvent = ReleaseOperationWaitEvent()
                    for subscription in releaseOperationWaitEventSubscriptions {
                        subscription.emit(operationWaitEvent)
                    }
        #endif
        await releaseTask.result
    }

    private func createRoom(roomID: String, options: RoomOptions) async throws -> RoomFactory.Room {
        let room = try await roomFactory.createRoom(realtime: realtime, chatAPI: chatAPI, roomID: roomID, options: options, logger: logger)
        roomStates[roomID] = .roomMapEntry(.created(room: room))
        return room
    }

    #if DEBUG
        // TODO: what is this? check it still makes sense in our tests
        internal func testsOnly_hasExistingRoomWithID(_ roomID: String) -> Bool {
            roomStates[roomID] != nil
        }
    #endif

    internal func release(roomID: String) async throws {
        guard let roomState = roomStates[roomID] else {
            // CHA-RC1g2 (no-op)
            return
        }

        switch roomState {
        case let .releaseOperationInProgress(releaseTask):
            // CHA-RC1g3
            await waitForReleaseTask(releaseTask)
        case let .roomMapEntry(
            .requestAwaitingRelease(
                releaseTask: releaseTask,
                _,
                _,
                failCreationTask: failCreationTask
            )
        ):
            // CHA-RC1g4
            failCreationTask(ARTErrorInfo(chatError: .roomReleasedBeforeOperationCompleted))
            await waitForReleaseTask(releaseTask)
        case let .roomMapEntry(.created(room: room)):
            // TODO: this (and creationTask) is a different approach to that taken in the lifecycle manager for waiting; maybe this is neater even though you could argue there's an unnecessary task here; also you don't have to worry about task priorities
            // TODO: explain that we expect releaseTask to happen afterwards, always, so that state changes happen in correct order
            let releaseTask = Task {
                // Clear the `.releaseOperationInProgress` state (written in a `defer` in case `room.release()` becomes throwing in the future)
                defer { roomStates.removeValue(forKey: roomID) }
                await room.release()
            }

            // This also achieves CHA-RC1g5 (remove room from room map)
            roomStates[roomID] = .releaseOperationInProgress(releaseTask: releaseTask)

            await releaseTask.value
        }
    }
}
