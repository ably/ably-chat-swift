import Ably
@testable import AblyChat

actor MockRoomLifecycleManager: RoomLifecycleManager {
    private let attachResult: Result<Void, ARTErrorInfo>?
    private let detachResult: Result<Void, ARTErrorInfo>?
    private let resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ARTErrorInfo>?

    private(set) var attachCallCount = 0
    private(set) var detachCallCount = 0
    private(set) var releaseCallCount = 0
    private(set) var waitCallCount = 0

    private let _roomStatus: RoomStatus?
    private var subscriptions = SubscriptionStorage<RoomStatusChange>()

    init(
        attachResult: Result<Void, ARTErrorInfo>? = nil,
        detachResult: Result<Void, ARTErrorInfo>? = nil,
        roomStatus: RoomStatus? = nil,
        resultOfWaitToBeAblePerformPresenceOperations: Result<Void, ARTErrorInfo>? = nil
    ) {
        self.attachResult = attachResult
        self.detachResult = detachResult
        resultOfWaitToBeAbleToPerformPresenceOperations = resultOfWaitToBeAblePerformPresenceOperations
        _roomStatus = roomStatus
    }

    func performAttachOperation() async throws(InternalError) {
        attachCallCount += 1
        emitStatusChange(.init(current: .attaching(error: nil), previous: _roomStatus ?? .initialized))
        if resultOfWaitToBeAbleToPerformPresenceOperations == nil {
            guard let attachResult else {
                fatalError("In order to call performAttachOperation, attachResult must be passed to the initializer")
            }
            do {
                try attachResult.get()
            } catch {
                throw error.toInternalError()
            }
        }
    }

    func performDetachOperation() async throws(InternalError) {
        detachCallCount += 1
        guard let detachResult else {
            fatalError("In order to call performDetachOperation, detachResult must be passed to the initializer")
        }
        do {
            try detachResult.get()
        } catch {
            throw error.toInternalError()
        }
    }

    func performReleaseOperation() async {
        releaseCallCount += 1
    }

    var roomStatus: RoomStatus {
        guard let roomStatus = _roomStatus else {
            fatalError("In order to call roomStatus, roomStatus must be passed to the initializer")
        }
        return roomStatus
    }

    func onRoomStatusChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange> {
        subscriptions.create(bufferingPolicy: bufferingPolicy)
    }

    func emitStatusChange(_ statusChange: RoomStatusChange) {
        subscriptions.emit(statusChange)
    }

    func waitToBeAbleToPerformPresenceOperations(requestedByFeature _: RoomFeature) async throws(InternalError) {
        waitCallCount += 1
        guard let resultOfWaitToBeAbleToPerformPresenceOperations else {
            fatalError("resultOfWaitToBeAblePerformPresenceOperations must be set before waitToBeAbleToPerformPresenceOperations is called")
        }
        do {
            try resultOfWaitToBeAbleToPerformPresenceOperations.get()
        } catch {
            throw error.toInternalError()
        }
    }
}
