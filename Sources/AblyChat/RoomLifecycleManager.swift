import Ably

@MainActor
internal protocol RoomLifecycleManager: Sendable {
    associatedtype StatusSubscription: AblyChat.StatusSubscription

    func performAttachOperation() async throws(ErrorInfo)
    func performDetachOperation() async throws(ErrorInfo)
    func performReleaseOperation() async
    var roomStatus: RoomStatus { get }
    var error: ErrorInfo? { get }
    @discardableResult
    func onRoomStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> StatusSubscription

    /// Waits until we can perform presence operations on this room's channel without triggering an implicit attach.
    ///
    /// Implements the checks described by CHA-PR3d, CHA-PR3e, and CHA-PR3h (and similar ones described by other functionality that performs channel presence operations). Namely:
    ///
    /// - CHA-RL9, which is invoked by CHA-PR3d, CHA-PR10d, CHA-PR6c: If the room is in the ATTACHING status, it waits for the next room status change. If the new status is ATTACHED, it returns. Else, it throws an `ErrorInfo` derived from ``InternalError/roomTransitionedToInvalidStateForPresenceOperation(cause:)``.
    /// - CHA-PR3e, CHA-PR10e, CHA-PR6d: If the room is in the ATTACHED status, it returns immediately.
    /// - CHA-PR3h, CHA-PR10h, CHA-PR6h: If the room is in any other status, it throws an `ErrorInfo` derived from ``InternalError/presenceOperationRequiresRoomAttach(feature:)``.
    ///
    /// - Parameters:
    ///   - requester: The room feature that wishes to perform a presence operation. This is only used for customising the message of the thrown error.
    func waitToBeAbleToPerformPresenceOperations(requestedByFeature requester: RoomFeature) async throws(ErrorInfo)

    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> StatusSubscription
}

@MainActor
internal protocol RoomLifecycleManagerFactory: Sendable {
    associatedtype Manager: RoomLifecycleManager

    func createManager(
        channel: any InternalRealtimeChannelProtocol,
        logger: any InternalLogger,
    ) -> Manager
}

internal final class DefaultRoomLifecycleManagerFactory: RoomLifecycleManagerFactory {
    private let clock = DefaultSimpleClock()

    internal func createManager(
        channel: any InternalRealtimeChannelProtocol,
        logger: any InternalLogger,
    ) -> DefaultRoomLifecycleManager {
        .init(
            channel: channel,
            logger: logger,
            clock: clock,
        )
    }
}

private extension RoomStatus {
    init(channelState: ARTRealtimeChannelState) {
        switch channelState {
        case .initialized:
            self = .initialized
        case .attaching:
            self = .attaching
        case .attached:
            self = .attached
        case .detaching:
            self = .detaching
        case .detached:
            self = .detached
        case .suspended:
            self = .suspended
        case .failed:
            self = .failed
        @unknown default:
            fatalError("Unknown channel state \(channelState)")
        }
    }
}

internal class DefaultRoomLifecycleManager: RoomLifecycleManager {
    // MARK: - Constant properties

    private let logger: any InternalLogger
    private let clock: any SimpleClock
    private let channel: any InternalRealtimeChannelProtocol

    // MARK: - Variable properties

    internal private(set) var roomStatus: RoomStatus
    internal private(set) var error: ErrorInfo?
    private var currentOperationID: UUID?

    // CHA-RL13
    private var hasAttachedOnce: Bool
    internal var testsOnly_hasAttachedOnce: Bool {
        hasAttachedOnce
    }

    // CHA-RL14
    private var isExplicitlyDetached: Bool
    internal var testsOnly_isExplicitlyDetached: Bool {
        isExplicitlyDetached
    }

    private var channelStateEventListener: ARTEventListener!
    private let roomStatusChangeSubscriptions = StatusSubscriptionStorage<RoomStatusChange>()
    private let discontinuitySubscriptions = StatusSubscriptionStorage<ErrorInfo>()
    private var operationResultContinuations = OperationResultContinuations()

    // MARK: - Initializers and `deinit`

    internal convenience init(
        channel: any InternalRealtimeChannelProtocol,
        logger: any InternalLogger,
        clock: any SimpleClock,
    ) {
        self.init(
            roomStatus: nil,
            hasAttachedOnce: nil,
            isExplicitlyDetached: nil,
            channel: channel,
            logger: logger,
            clock: clock,
        )
    }

    #if DEBUG
        internal convenience init(
            testsOnly_roomStatus roomStatus: RoomStatus? = nil,
            testsOnly_hasAttachedOnce hasAttachedOnce: Bool? = nil,
            testsOnly_isExplicitlyDetached isExplicitlyDetached: Bool? = nil,
            channel: any InternalRealtimeChannelProtocol,
            logger: any InternalLogger,
            clock: any SimpleClock,
        ) {
            self.init(
                roomStatus: roomStatus,
                hasAttachedOnce: hasAttachedOnce,
                isExplicitlyDetached: isExplicitlyDetached,
                channel: channel,
                logger: logger,
                clock: clock,
            )
        }
    #endif

    private init(
        roomStatus: RoomStatus?,
        hasAttachedOnce: Bool?,
        isExplicitlyDetached: Bool?,
        channel: any InternalRealtimeChannelProtocol,
        logger: any InternalLogger,
        clock: any SimpleClock,
    ) {
        self.roomStatus = roomStatus ?? .initialized
        self.hasAttachedOnce = hasAttachedOnce ?? false
        self.isExplicitlyDetached = isExplicitlyDetached ?? false
        self.channel = channel
        self.logger = logger
        self.clock = clock

        // CHA-RL11, CHA-RL12: listen for state events from our channel
        channelStateEventListener = channel.on { [weak self] event in
            self?.didReceiveChannelStateEvent(event)
        }
    }

    deinit {
        // This was a case of "do something that the compiler accepts"; there might be a better way.
        // (https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md sounds relevant too.)
        let (channelStateEventListener, channel) = (self.channelStateEventListener as ARTEventListener, self.channel)
        Task { @MainActor in
            channel.off(channelStateEventListener)
        }
    }

    // MARK: - Room status and its changes

    @discardableResult
    internal func onRoomStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> DefaultStatusSubscription {
        roomStatusChangeSubscriptions.create(callback)
    }

    /// Updates ``roomStatus`` and emits a status change event.
    private func changeStatus(to new: RoomStatus, error: ErrorInfo? = nil) {
        logger.log(message: "Transitioning from \(roomStatus) to \(new)", level: .info)
        let previous = roomStatus
        roomStatus = new
        self.error = error

        let statusChange = RoomStatusChange(current: roomStatus, previous: previous, error: error)
        roomStatusChangeSubscriptions.emit(statusChange)
    }

    // MARK: - Handling channel state changes

    /// Implements CHA-RL11 and CHA-RL12's channel event handling.
    private func didReceiveChannelStateEvent(_ event: ChannelStateChange) {
        logger.log(message: "Got channel state event \(event)", level: .info)

        // CHA-RL11b
        if event.event != .update, !hasOperationInProgress {
            // CHA-RL11c
            changeStatus(
                to: .init(channelState: event.current),
                error: event.reason,
            )
        }

        switch event.event {
        // CHA-RL12a
        case .update, .attached:
            // CHA-RL12b
            //
            // Note that our mechanism for deciding whether a channel state event represents a discontinuity depends on the property that when we call attach() on a channel, the ATTACHED state change that this provokes is received before the call to attach() returns. This property is not in general guaranteed in ably-cocoa, which allows its callbacks to be dispatched to a user-provided queue as specified by the `dispatchQueue` client option. This is why we add the requirement that the ably-cocoa client be configured to use the main queue as its `dispatchQueue` (as enforced by toAblyCocoaCallback in InternalAblyCocoaTypes.swift).
            if !event.resumed, hasAttachedOnce, !isExplicitlyDetached {
                let error = InternalError.roomDiscontinuity(cause: event.reason).toErrorInfo()
                logger.log(message: "Emitting discontinuity event \(error)", level: .info)
                emitDiscontinuity(error)
            }
        default:
            break
        }
    }

    @discardableResult
    internal func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> DefaultStatusSubscription {
        discontinuitySubscriptions.create(callback)
    }

    private func emitDiscontinuity(_ error: ErrorInfo) {
        discontinuitySubscriptions.emit(error)
    }

    // MARK: - Operation handling

    /// Whether the room lifecycle manager currently has a room lifecycle operation in progress.
    private var hasOperationInProgress: Bool {
        currentOperationID != nil
    }

    /// Stores bookkeeping information needed for allowing one operation to await the result of another.
    private struct OperationResultContinuations {
        typealias Continuation = CheckedContinuation<Result<Void, ErrorInfo>, Never>

        private var operationResultContinuationsByOperationID: [UUID: [Continuation]] = [:]

        mutating func addContinuation(_ continuation: Continuation, forResultOfOperationWithID operationID: UUID) {
            operationResultContinuationsByOperationID[operationID, default: []].append(continuation)
        }

        mutating func removeContinuationsForResultOfOperationWithID(_ waitedOperationID: UUID) -> [Continuation] {
            operationResultContinuationsByOperationID.removeValue(forKey: waitedOperationID) ?? []
        }
    }

    #if DEBUG
        /// The manager emits an `OperationWaitEvent` each time one room lifecycle operation is going to wait for another to complete. These events are emitted to support testing of the manager; see ``testsOnly_subscribeToOperationWaitEvents``.
        internal struct OperationWaitEvent: Equatable {
            /// The ID of the operation which initiated the wait. It is waiting for the operation with ID ``waitedOperationID`` to complete.
            internal var waitingOperationID: UUID?
            /// The ID of the operation whose completion will be awaited.
            internal var waitedOperationID: UUID
        }

        /// Supports the ``testsOnly_subscribeToOperationWaitEvents()`` method.
        private let operationWaitEventSubscriptions = SubscriptionStorage<OperationWaitEvent>()

        /// Returns a subscription which emits an event each time one room lifecycle operation is going to wait for another to complete.
        internal func testsOnly_subscribeToOperationWaitEvents(_ callback: @escaping @MainActor (OperationWaitEvent) -> Void) -> any Subscription {
            operationWaitEventSubscriptions.create(callback)
        }
    #endif

    private enum OperationWaitRequester {
        case anotherOperation(operationID: UUID)
        case waitToBeAbleToPerformPresenceOperations

        internal var loggingDescription: String {
            switch self {
            case let .anotherOperation(operationID):
                "Operation \(operationID)"
            case .waitToBeAbleToPerformPresenceOperations:
                "waitToBeAbleToPerformPresenceOperations"
            }
        }

        internal var waitingOperationID: UUID? {
            switch self {
            case let .anotherOperation(operationID):
                operationID
            case .waitToBeAbleToPerformPresenceOperations:
                nil
            }
        }
    }

    /// Waits for the operation with ID `waitedOperationID` to complete, re-throwing any error thrown by that operation.
    ///
    /// Note that this method currently treats all waited operations as throwing. If you wish to wait for an operation that you _know_ to be non-throwing (which the RELEASE operation currently is) then you'll need to call this method with `try!` or equivalent. (It might be possible to improve this in the future, but I didn't want to put much time into figuring it out.)
    ///
    /// It is guaranteed that if you call this method from a manager-isolated method, and subsequently call ``operationWithID(_:,didCompleteWithResult:)`` from another manager-isolated method, then the call to this method will return.
    ///
    /// - Parameters:
    ///   - waitedOperationID: The ID of the operation whose completion will be awaited.
    ///   - requester: A description of who is awaiting this result. Only used for logging.
    private func waitForCompletionOfOperationWithID(
        _ waitedOperationID: UUID,
        requester: OperationWaitRequester,
    ) async throws(ErrorInfo) {
        logger.log(message: "\(requester.loggingDescription) started waiting for result of operation \(waitedOperationID)", level: .debug)

        do {
            let result = await withCheckedContinuation { (continuation: OperationResultContinuations.Continuation) in
                // My "it is guaranteed" in the documentation for this method is really more of an "I hope that", because it's based on my pretty vague understanding of Swift concurrency concepts; namely, I believe that if you call this manager-isolated `async` method from another manager-isolated method, the initial synchronous part of this method — in particular the call to `addContinuation` below — will occur _before_ the call to this method suspends. (I think this can be roughly summarised as "calls to async methods on self don't do actor hopping" but I could be completely misusing a load of Swift concurrency vocabulary there.)
                operationResultContinuations.addContinuation(continuation, forResultOfOperationWithID: waitedOperationID)

                #if DEBUG
                    let operationWaitEvent = OperationWaitEvent(waitingOperationID: requester.waitingOperationID, waitedOperationID: waitedOperationID)
                    operationWaitEventSubscriptions.emit(operationWaitEvent)
                #endif
            }

            try result.get()

            logger.log(message: "\(requester.loggingDescription) completed waiting for result of operation \(waitedOperationID), which completed successfully", level: .debug)
        } catch {
            logger.log(message: "\(requester.loggingDescription) completed waiting for result of operation \(waitedOperationID), which threw error \(error)", level: .debug)
            throw error
        }
    }

    /// Operations should call this when they have completed, in order to complete any waits initiated by ``waitForCompletionOfOperationWithID(_:waitingOperationID:)``.
    private func operationWithID(_ operationID: UUID, didCompleteWithResult result: Result<Void, ErrorInfo>) {
        logger.log(message: "Operation \(operationID) completed with result \(result)", level: .debug)
        let continuationsToResume = operationResultContinuations.removeContinuationsForResultOfOperationWithID(operationID)

        for continuation in continuationsToResume {
            continuation.resume(returning: result)
        }
    }

    /// Executes a function that represents a room lifecycle operation.
    ///
    /// - Note: Note that `DefaultRoomLifecycleManager` does not implement any sort of mutual exclusion mechanism that _enforces_ that one room lifecycle operation must wait for another (e.g. it is _not_ a queue); each operation needs to implement its own logic for whether it should proceed in the presence of other in-progress operations.
    ///
    /// Note that this method currently treats all performed operations as throwing. If you wish to wait for an operation that you _know_ to be non-throwing (which the RELEASE operation currently is) then you'll need to call this method with `try!` or equivalent. (It might be possible to improve this in the future, but I didn't want to put much time into figuring it out.)
    ///
    /// - Parameters:
    ///   - forcedOperationID: Forces the operation to have a given ID. In combination with the ``testsOnly_subscribeToOperationWaitEvents`` API, this allows tests to verify that one test-initiated operation is waiting for another test-initiated operation.
    ///   - body: The implementation of the operation to be performed. Once this function returns or throws an error, the operation is considered to have completed, and any waits for this operation's completion initiated via ``waitForCompletionOfOperationWithID(_:waitingOperationID:)`` will complete.
    private func performAnOperation(
        forcingOperationID forcedOperationID: UUID?,
        _ body: (UUID) async throws(ErrorInfo) -> Void,
    ) async throws(ErrorInfo) {
        let operationID = forcedOperationID ?? UUID()
        logger.log(message: "Performing operation \(operationID)", level: .debug)
        let result: Result<Void, ErrorInfo>
        do {
            // My understanding (based on what the compiler allows me to do, and a vague understanding of how actors work) is that inside this closure you can write code as if it were a method on the manager itself — i.e. with synchronous access to the manager's state. But I currently lack the Swift concurrency vocabulary to explain exactly why this is the case.
            try await body(operationID)
            result = .success(())
        } catch {
            result = .failure(error)
        }

        operationWithID(operationID, didCompleteWithResult: result)

        try result.get()
    }

    // MARK: - ATTACH operation

    internal func performAttachOperation() async throws(ErrorInfo) {
        try await _performAttachOperation(forcingOperationID: nil)
    }

    internal func performAttachOperation(testsOnly_forcingOperationID forcedOperationID: UUID? = nil) async throws(ErrorInfo) {
        try await _performAttachOperation(forcingOperationID: forcedOperationID)
    }

    /// Implements CHA-RL1's `ATTACH` operation.
    ///
    /// - Parameters:
    ///   - forcedOperationID: Allows tests to force the operation to have a given ID. In combination with the ``testsOnly_subscribeToOperationWaitEvents`` API, this allows tests to verify that one test-initiated operation is waiting for another test-initiated operation.
    private func _performAttachOperation(forcingOperationID forcedOperationID: UUID?) async throws(ErrorInfo) {
        try await performAnOperation(forcingOperationID: forcedOperationID) { operationID throws(ErrorInfo) in
            try await bodyOfAttachOperation(operationID: operationID)
        }
    }

    private func bodyOfAttachOperation(operationID: UUID) async throws(ErrorInfo) {
        switch roomStatus {
        case .attached:
            // CHA-RL1a
            return
        case .releasing:
            // CHA-RL1b
            throw InternalError.roomIsReleasing.toErrorInfo()
        case .released:
            // CHA-RL1l
            throw InternalError.roomInInvalidStateForAttach(roomStatus).toErrorInfo()
        default:
            break
        }

        // CHA-RL1d
        if let currentOperationID {
            try? await waitForCompletionOfOperationWithID(currentOperationID, requester: .anotherOperation(operationID: operationID))
        }

        currentOperationID = operationID
        defer { currentOperationID = nil }

        // CHA-RL1e
        changeStatus(to: .attaching, error: nil)

        // CHA-RL1k
        do {
            try await channel.attach()
        } catch {
            // CHA-RL1k2, CHA-RL1k3
            let channelState = channel.state
            logger.log(message: "Failed to attach channel, error \(error), channel now in \(channelState)", level: .info)
            changeStatus(to: .init(channelState: channelState), error: error)
            throw error
        }

        // CHA-RL1k1
        isExplicitlyDetached = false
        hasAttachedOnce = true
        changeStatus(to: .attached, error: nil)
    }

    // MARK: - DETACH operation

    internal func performDetachOperation() async throws(ErrorInfo) {
        try await _performDetachOperation(forcingOperationID: nil)
    }

    internal func performDetachOperation(testsOnly_forcingOperationID forcedOperationID: UUID? = nil) async throws(ErrorInfo) {
        try await _performDetachOperation(forcingOperationID: forcedOperationID)
    }

    /// Implements CHA-RL2's DETACH operation.
    ///
    /// - Parameters:
    ///   - forcedOperationID: Allows tests to force the operation to have a given ID. In combination with the ``testsOnly_subscribeToOperationWaitEvents`` API, this allows tests to verify that one test-initiated operation is waiting for another test-initiated operation.
    private func _performDetachOperation(forcingOperationID forcedOperationID: UUID?) async throws(ErrorInfo) {
        try await performAnOperation(forcingOperationID: forcedOperationID) { operationID throws(ErrorInfo) in
            try await bodyOfDetachOperation(operationID: operationID)
        }
    }

    private func bodyOfDetachOperation(operationID: UUID) async throws(ErrorInfo) {
        switch roomStatus {
        case .detached:
            // CHA-RL2a
            return
        case .releasing:
            // CHA-RL2b
            throw InternalError.roomIsReleasing.toErrorInfo()
        case .released, .failed:
            // CHA-RL2l, CHA-RL2m
            throw InternalError.roomInInvalidStateForDetach(roomStatus).toErrorInfo()
        case .initialized, .attaching, .attached, .detaching, .suspended:
            break
        }

        // CHA-RL2i
        if let currentOperationID {
            try? await waitForCompletionOfOperationWithID(currentOperationID, requester: .anotherOperation(operationID: operationID))
        }

        currentOperationID = operationID
        defer { currentOperationID = nil }

        // CHA-RL2j
        changeStatus(to: .detaching, error: nil)

        // CHA-RL2k
        do {
            try await channel.detach()
        } catch {
            // CHA-RL2k2, CHA-RL2k3
            let channelState = channel.state
            logger.log(message: "Failed to detach channel, error \(error), channel now in \(channelState)", level: .info)
            changeStatus(to: .init(channelState: channelState), error: error)
            throw error
        }

        // CHA-RL2k1
        isExplicitlyDetached = true
        changeStatus(to: .detached, error: nil)
    }

    // MARK: - RELEASE operation

    internal func performReleaseOperation() async {
        await _performReleaseOperation(forcingOperationID: nil)
    }

    internal func performReleaseOperation(testsOnly_forcingOperationID forcedOperationID: UUID? = nil) async {
        await _performReleaseOperation(forcingOperationID: forcedOperationID)
    }

    /// Implements CHA-RL3's RELEASE operation.
    ///
    /// - Parameters:
    ///   - forcedOperationID: Allows tests to force the operation to have a given ID. In combination with the ``testsOnly_subscribeToOperationWaitEvents`` API, this allows tests to verify that one test-initiated operation is waiting for another test-initiated operation.
    internal func _performReleaseOperation(forcingOperationID forcedOperationID: UUID? = nil) async {
        // See note on performAnOperation for the current need for this force try
        // swiftlint:disable:next force_try
        try! await performAnOperation(forcingOperationID: forcedOperationID) { operationID in
            await bodyOfReleaseOperation(operationID: operationID)
        }
    }

    private func bodyOfReleaseOperation(operationID: UUID) async {
        switch roomStatus {
        case .released:
            // CHA-RL3a
            return
        case
            // CHA-RL3b
            .detached,
            // CHA-RL3j
            .initialized:
            changeStatus(to: .released)
            return
        default:
            break
        }

        // CHA-RL3k
        if let currentOperationID {
            try? await waitForCompletionOfOperationWithID(currentOperationID, requester: .anotherOperation(operationID: operationID))
        }

        currentOperationID = operationID
        defer { currentOperationID = nil }

        // CHA-RL3m
        changeStatus(to: .releasing)

        // CHA-RL3n
        while true {
            // CHA-RL3n1
            if channel.state == .failed {
                logger.log(message: "Channel is FAILED; skipping detach", level: .info)
                break
            }

            do {
                // CHA-RL3n2
                logger.log(message: "Detaching channel", level: .info)
                try await channel.detach()
                break
            } catch {
                // CHA-RL3n3
                if channel.state == .failed {
                    logger.log(message: "Channel is FAILED after detach; exiting detach loop", level: .info)
                    break
                }

                // CHA-RL3n4: Retry until detach succeeds, with a pause before each attempt
                let waitDuration = 0.25
                logger.log(message: "Failed to detach channel, error \(error). Will retry in \(waitDuration)s.", level: .info)
                // We're using an unstructured task so that this wait completes regardless of cancellation of the task that performed the release operation. But TODO think about the right behaviour in the case where the task is cancelled (as part of the broader https://github.com/ably-labs/ably-chat-swift/issues/29 for handling task cancellation)
                _ = await Task {
                    try await clock.sleep(timeInterval: waitDuration)
                }.result

                // Loop repeats
            }
        }

        // CHA-RL3o
        changeStatus(to: .released)
    }

    // MARK: - Waiting to be able to perform presence operations

    internal func waitToBeAbleToPerformPresenceOperations(requestedByFeature requester: RoomFeature) async throws(ErrorInfo) {
        // Although this method's implementation only uses the manager's public
        // API, it's implemented as a method on the manager itself, so that the
        // implementation is isolated to the manager and hence doesn't "miss"
        // any status changes. (There may be other ways to achieve the same
        // effect; can revisit.)

        switch roomStatus {
        case .attaching:
            // CHA-RL9, which is invoked by CHA-PR3d, CHA-PR10d, CHA-PR6c

            // CHA-RL9a
            var nextRoomStatusSubscription: StatusSubscription!
            var nextRoomStatusChange: RoomStatusChange!
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, _>) in
                self.logger.log(message: "waitToBeAbleToPerformPresenceOperations waiting for status change", level: .debug)
                #if DEBUG
                    self.statusChangeWaitEventSubscriptions.emit(.init())
                #endif
                nextRoomStatusSubscription = self.onRoomStatusChange { [weak self] statusChange in
                    nextRoomStatusChange = statusChange
                    self?.logger.log(message: "waitToBeAbleToPerformPresenceOperations got status change \(String(describing: nextRoomStatusChange))", level: .debug)
                    continuation.resume()
                }
            }
            nextRoomStatusSubscription.off()
            // CHA-RL9b
            guard case .attached = nextRoomStatusChange.current, nextRoomStatusChange.error == nil else {
                // CHA-RL9c
                throw InternalError.roomTransitionedToInvalidStateForPresenceOperation(cause: nextRoomStatusChange.error).toErrorInfo()
            }
        case .attached:
            // CHA-PR3e, CHA-PR10e, CHA-PR6d
            break
        default:
            // CHA-PR3h, CHA-PR10h, CHA-PR6h
            throw InternalError.presenceOperationRequiresRoomAttach(feature: requester).toErrorInfo()
        }
    }

    #if DEBUG
        /// The manager emits a `StatusChangeWaitEvent` each time ``waitToBeAbleToPerformPresenceOperations(requestedByFeature:)`` is going to wait for a room status change. These events are emitted to support testing of the manager; see ``testsOnly_subscribeToStatusChangeWaitEvents``.
        internal struct StatusChangeWaitEvent: Equatable {
            // Nothing here currently, just created this type for consistency with OperationWaitEvent
        }

        /// Supports the ``testsOnly_subscribeToStatusChangeWaitEvents()`` method.
        private let statusChangeWaitEventSubscriptions = SubscriptionStorage<StatusChangeWaitEvent>()

        /// Returns a subscription which emits an event each time ``waitToBeAbleToPerformPresenceOperations(requestedByFeature:)`` is going to wait for a room status change.
        internal func testsOnly_subscribeToStatusChangeWaitEvents(_ callback: @escaping @MainActor (StatusChangeWaitEvent) -> Void) -> any Subscription {
            statusChangeWaitEventSubscriptions.create(callback)
        }
    #endif
}
