import Ably

/**
 * Manages the lifecycle of chat rooms.
 */
@MainActor
public protocol Rooms: AnyObject, Sendable {
    /**
     * Gets a room reference by name. The Rooms class ensures that only one reference
     * exists for each room. A new reference object is created if it doesn't already
     * exist, or if the one used previously was released using ``release(name:)``.
     *
     * Always call `release(name:)` after the ``Room`` object is no longer needed.
     *
     * If a call to this method is made for a room that is currently being released, then this it returns only when
     * the release operation is complete.
     *
     * If a call to this method is made, followed by a subsequent call to `release(name:)` before the `get(name:options:)` returns, then the
     * promise will throw an error.
     *
     * - Parameters:
     *   - name: The name of the room.
     *   - options: The options for the room.
     *
     * - Returns: A new or existing `Room` object.
     *
     * - Throws: `ARTErrorInfo` if a room with the same name but different options already exists.
     */
    func get(name: String, options: RoomOptions) async throws(ARTErrorInfo) -> any Room

    /// Same as calling ``get(name:options:)`` with `RoomOptions()`.
    ///
    /// The `Rooms` protocol provides a default implementation of this method.
    func get(name: String) async throws(ARTErrorInfo) -> any Room

    /**
     * Release the ``Room`` object if it exists. This method only releases the reference
     * to the Room object from the Rooms instance and detaches the room from Ably. It does not unsubscribe to any
     * events.
     *
     * After calling this function, the room object is no-longer usable. If you wish to get the room object again,
     * you must call ``Rooms/get(name:options:)``.
     *
     * Calling this function will abort any in-progress `get(name:options:)` calls for the same room.
     *
     * - Parameters:
     *   - name: The name of the room.
     */
    func release(name: String) async

    /**
     * Get the client options used to create the chat instance.
     *
     * - Returns: ``ClientOptions`` object.
     */
    nonisolated var clientOptions: ChatClientOptions { get }
}

public extension Rooms {
    func get(name: String) async throws(ARTErrorInfo) -> any Room {
        // CHA-RC4a
        try await get(name: name, options: .init())
    }
}

internal class DefaultRooms<RoomFactory: AblyChat.RoomFactory>: Rooms {
    private nonisolated let realtime: any InternalRealtimeClientProtocol
    private let chatAPI: ChatAPI

    #if DEBUG
        internal nonisolated var testsOnly_realtime: any InternalRealtimeClientProtocol {
            realtime
        }
    #endif

    internal nonisolated let clientOptions: ChatClientOptions

    private let logger: InternalLogger
    private let roomFactory: RoomFactory

    /// All the state that a `DefaultRooms` instance might hold for a given room name.
    private enum RoomState {
        /// There is no room map entry (see ``RoomMapEntry`` for meaning of this term) for this room name, but a CHA-RC1g release operation is in progress.
        case releaseOperationInProgress(releaseTask: Task<Void, Never>)

        /// There is a room map entry for this room name.
        case roomMapEntry(RoomMapEntry)
    }

    /// An entry in the “room map” that CHA-RC1f and CHA-RC1g refer to.
    private enum RoomMapEntry {
        /// The room has been requested, but is awaiting the completion of a CHA-RC1g release operation.
        case requestAwaitingRelease(
            // A task which provides the result of the pending release operation.
            releaseTask: Task<Void, Never>,
            // The options with which the room was requested.
            requestedOptions: RoomOptions,
            // A task that will return the result of this room fetch request.
            creationTask: Task<Result<RoomFactory.Room, InternalError>, Never>,
            // Calling this function will cause `creationTask` to fail with the given error.
            failCreation: @Sendable (InternalError) -> Void
        )

        /// The room has been created.
        case created(room: RoomFactory.Room)

        /// The room options that correspond to this room map entry (either the options that were passed to the pending room fetch request, or the options of the created room).
        var roomOptions: RoomOptions {
            switch self {
            case let .requestAwaitingRelease(_, requestedOptions: options, _, _):
                options
            case let .created(room):
                room.options
            }
        }

        /// Returns the room which this room map entry corresponds to. If the room map entry represents a pending request, it will return or throw with the result of this request.
        func waitForRoom() async throws(InternalError) -> RoomFactory.Room {
            switch self {
            case let .requestAwaitingRelease(_, _, creationTask: creationTask, _):
                try await creationTask.value.get()
            case let .created(room):
                room
            }
        }
    }

    /// The value for a given room name is the state that corresponds to that room name.
    private var roomStates: [String: RoomState] = [:]

    internal init(realtime: any InternalRealtimeClientProtocol, clientOptions: ChatClientOptions, logger: InternalLogger, roomFactory: RoomFactory) {
        self.realtime = realtime
        self.clientOptions = clientOptions
        self.logger = logger
        self.roomFactory = roomFactory
        chatAPI = ChatAPI(realtime: realtime)
    }

    /// The types of operation that this instance can perform.
    internal enum OperationType {
        /// A call to ``get(name:options:)``.
        case get
        /// A call to ``release(name:)``.
        case release
    }

    #if DEBUG
        internal struct OperationWaitEvent {
            internal var waitingOperationType: OperationType
            internal var waitedOperationType: OperationType
        }

        /// Supports the ``testsOnly_subscribeToOperationWaitEvents()`` method.
        private let operationWaitEventSubscriptions = SubscriptionStorage<OperationWaitEvent>()

        /// Returns a subscription which emits an event each time one operation is going to wait for another to complete.
        internal func testsOnly_subscribeToOperationWaitEvents(_ callback: @escaping @MainActor (OperationWaitEvent) -> Void) -> SubscriptionProtocol {
            operationWaitEventSubscriptions.create(callback)
        }

        private func emitOperationWaitEvent(waitingOperationType: OperationType, waitedOperationType: OperationType) {
            let operationWaitEvent = OperationWaitEvent(waitingOperationType: waitingOperationType, waitedOperationType: waitedOperationType)
            operationWaitEventSubscriptions.emit(operationWaitEvent)
        }
    #endif

    internal func get(name: String, options: RoomOptions) async throws(ARTErrorInfo) -> any Room {
        do throws(InternalError) {
            if let existingRoomState = roomStates[name] {
                switch existingRoomState {
                case let .roomMapEntry(existingRoomMapEntry):
                    // CHA-RC1f1
                    if existingRoomMapEntry.roomOptions != options {
                        throw ARTErrorInfo(
                            chatError: .inconsistentRoomOptions(requested: options, existing: existingRoomMapEntry.roomOptions)
                        ).toInternalError()
                    }

                    // CHA-RC1f2
                    logger.log(message: "Waiting for room from existing room map entry \(existingRoomMapEntry)", level: .debug)

                    #if DEBUG
                        emitOperationWaitEvent(waitingOperationType: .get, waitedOperationType: .get)
                    #endif

                    do {
                        let room = try await existingRoomMapEntry.waitForRoom()
                        logger.log(message: "Completed waiting for room from existing room map entry \(existingRoomMapEntry)", level: .debug)
                        return room
                    } catch {
                        logger.log(message: "Got error \(error) waiting for room from existing room map entry \(existingRoomMapEntry)", level: .debug)
                        throw error
                    }
                case let .releaseOperationInProgress(releaseTask: releaseTask):
                    let creationFailureFunctions = makeCreationFailureFunctions()

                    let creationTask = Task<Result<RoomFactory.Room, InternalError>, Never> {
                        do throws(InternalError) {
                            logger.log(message: "At start of room creation task", level: .debug)

                            // We wait for the first of the following events:
                            //
                            // - a creation failure is externally signalled, in which case we throw the corresponding error
                            // - the in-progress release operation completes
                            try await withTaskGroup(of: Result<Void, InternalError>.self) { group in
                                group.addTask {
                                    do throws(InternalError) {
                                        try await creationFailureFunctions.throwAnySignalledCreationFailure()
                                        return .success(())
                                    } catch {
                                        return .failure(error)
                                    }
                                }

                                group.addTask { [logger] in
                                    // This task is rather messy but its aim can be summarised as the following:
                                    //
                                    // - if releaseTask completes, then complete
                                    // - if the task is cancelled, then do not propagate the cancellation to releaseTask (because we haven’t properly thought through whether it can handle task cancellation; see existing TODO: https://github.com/ably/ably-chat-swift/issues/29), and do not wait for releaseTask to complete (because the CHA-RC1g4 failure is meant to happen immediately, not only once the release operation completes)

                                    logger.log(message: "Room creation waiting for completion of release operation", level: .debug)
                                    #if DEBUG
                                        await self.emitOperationWaitEvent(waitingOperationType: .get, waitedOperationType: .release)
                                    #endif

                                    let (stream, continuation) = AsyncStream<Void>.makeStream()
                                    Task.detached { // detached so as not to propagate task cancellation
                                        // CHA-RC1f4
                                        await releaseTask.value
                                        continuation.yield(())
                                        continuation.finish()
                                    }

                                    if await (stream.contains { _ in true }) {
                                        logger.log(message: "Room creation completed waiting for completion of release operation", level: .debug)
                                    } else {
                                        // Task was cancelled
                                        logger.log(message: "Room creation stopped waiting for completion of release operation", level: .debug)
                                    }

                                    return .success(())
                                }

                                // This pattern for waiting for the first of multiple tasks to complete is taken from here:
                                // https://forums.swift.org/t/accept-the-first-task-to-complete/54386
                                defer { group.cancelAll() }
                                return await group.next() ?? .success(())
                            }.get()

                            return try .success(createRoom(name: name, options: options))
                        } catch {
                            return .failure(error)
                        }
                    }

                    roomStates[name] = .roomMapEntry(
                        .requestAwaitingRelease(
                            releaseTask: releaseTask,
                            requestedOptions: options,
                            creationTask: creationTask,
                            failCreation: creationFailureFunctions.failCreation
                        )
                    )

                    return try await creationTask.value.get()
                }
            }

            // CHA-RC1f3
            return try createRoom(name: name, options: options)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    /// Creates two functions, `failCreation` and `throwAnySignalledCreationFailure`. The latter is an async function that waits until the former is called with an error as an argument; it then throws this error.
    private func makeCreationFailureFunctions() -> (failCreation: @Sendable (InternalError) -> Void, throwAnySignalledCreationFailure: @Sendable () async throws(InternalError) -> Void) {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<Void, InternalError>.self)

        return (
            failCreation: { @Sendable [logger] (error: InternalError) in
                logger.log(message: "Recieved request to fail room creation with error \(error)", level: .debug)
                continuation.yield(.failure(error))
                continuation.finish()
            },
            throwAnySignalledCreationFailure: { @Sendable [logger] () throws(InternalError) in
                logger.log(message: "Waiting for room creation failure request", level: .debug)
                do throws(InternalError) {
                    try await stream.first { _ in true }?.get()
                } catch {
                    throw error
                }
                logger.log(message: "Wait for room creation failure request completed without error", level: .debug)
            }
        )
    }

    private func waitForOperation(_ operationTask: Task<Void, Never>, waitingOperationType: OperationType, waitedOperationType: OperationType) async {
        logger.log(message: "\(waitingOperationType) operation waiting for in-progress \(waitedOperationType) operation to complete", level: .debug)
        #if DEBUG
            emitOperationWaitEvent(waitingOperationType: waitingOperationType, waitedOperationType: waitedOperationType)
        #endif
        await operationTask.value
        logger.log(message: "\(waitingOperationType) operation completed waiting for in-progress \(waitedOperationType) operation to complete", level: .debug)
    }

    private func createRoom(name: String, options: RoomOptions) throws(InternalError) -> RoomFactory.Room {
        logger.log(message: "Creating room with name \(name), options \(options)", level: .debug)
        let room = try roomFactory.createRoom(realtime: realtime, chatAPI: chatAPI, name: name, options: options, logger: logger)
        roomStates[name] = .roomMapEntry(.created(room: room))
        return room
    }

    #if DEBUG
        internal func testsOnly_hasRoomMapEntryWithName(_ name: String) -> Bool {
            guard let roomState = roomStates[name] else {
                return false
            }

            return if case .roomMapEntry = roomState {
                true
            } else {
                false
            }
        }
    #endif

    internal func release(name: String) async {
        guard let roomState = roomStates[name] else {
            // CHA-RC1g2 (no-op)
            return
        }

        switch roomState {
        case let .releaseOperationInProgress(releaseTask):
            // CHA-RC1g3
            await waitForOperation(releaseTask, waitingOperationType: .release, waitedOperationType: .release)
        case let .roomMapEntry(
            .requestAwaitingRelease(
                releaseTask: releaseTask,
                _,
                _,
                failCreation: failCreation
            )
        ):
            // CHA-RC1g4
            logger.log(message: "Release operation requesting failure of in-progress room creation request", level: .debug)
            failCreation(ARTErrorInfo(chatError: .roomReleasedBeforeOperationCompleted).toInternalError())
            await waitForOperation(releaseTask, waitingOperationType: .release, waitedOperationType: .release)
        case let .roomMapEntry(.created(room: room)):
            let releaseTask = Task {
                logger.log(message: "Release operation waiting for room release operation to complete", level: .debug)
                // Clear the `.releaseOperationInProgress` state (written in a `defer` in case `room.release()` becomes throwing in the future)
                defer { roomStates.removeValue(forKey: name) }
                await room.release()
                logger.log(message: "Release operation completed waiting for room release operation to complete", level: .debug)
            }

            // Note that, since we’re in an actor (specifically, the MainActor), we expect `releaseTask` to always be executed _after_ this synchronous code section, meaning that the `roomStates` mutations happen in the correct order

            // This also achieves CHA-RC1g5 (remove room from room map)
            roomStates[name] = .releaseOperationInProgress(releaseTask: releaseTask)

            await releaseTask.value
        }
    }
}
