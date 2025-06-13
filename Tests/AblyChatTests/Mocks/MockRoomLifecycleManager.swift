import Ably
@testable import AblyChat

class MockRoomLifecycleManager: RoomLifecycleManager {
    let callRecorder = MockMethodCallRecorder()
    private let attachResult: Result<Void, ARTErrorInfo>?
    private(set) var attachCallCount = 0
    private let detachResult: Result<Void, ARTErrorInfo>?
    private(set) var detachCallCount = 0
    private(set) var releaseCallCount = 0
    private let _roomStatus: RoomStatus?
    private let roomStatusSubscriptions = SubscriptionStorage<RoomStatusChange>()
    private let discontinuitySubscriptions = SubscriptionStorage<DiscontinuityEvent>()
    private let resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ARTErrorInfo>?

    init(attachResult: Result<Void, ARTErrorInfo>? = nil, detachResult: Result<Void, ARTErrorInfo>? = nil, roomStatus: RoomStatus? = nil, resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ARTErrorInfo> = .success(())) {
        self.attachResult = attachResult
        self.detachResult = detachResult
        self.resultOfWaitToBeAbleToPerformPresenceOperations = resultOfWaitToBeAbleToPerformPresenceOperations
        _roomStatus = roomStatus
    }

    func performAttachOperation() async throws(InternalError) {
        attachCallCount += 1
        guard let attachResult else {
            fatalError("In order to call performAttachOperation, attachResult must be passed to the initializer")
        }
        do {
            try attachResult.get()
        } catch {
            throw error.toInternalError()
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

    func onRoomStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange> {
        roomStatusSubscriptions.create(bufferingPolicy: bufferingPolicy)
    }

    func emitStatusChange(_ statusChange: RoomStatusChange) {
        roomStatusSubscriptions.emit(statusChange)
    }

    func waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature) async throws(InternalError) {
        guard let resultOfWaitToBeAbleToPerformPresenceOperations else {
            fatalError("resultOfWaitToBeAblePerformPresenceOperations must be set before waitToBeAbleToPerformPresenceOperations is called")
        }
        callRecorder.addRecord(
            signature: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "\(requestedByFeature)"]
        )
        do {
            try resultOfWaitToBeAbleToPerformPresenceOperations.get()
        } catch {
            throw error.toInternalError()
        }
    }

    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        discontinuitySubscriptions.create(bufferingPolicy: bufferingPolicy)
    }

    func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) {
        discontinuitySubscriptions.emit(discontinuity)
    }
}
