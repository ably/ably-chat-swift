import Ably
@testable import AblyChat

class MockRoomLifecycleManager: RoomLifecycleManager {
    let callRecorder = MockMethodCallRecorder()
    private let attachResult: Result<Void, ErrorInfo>?
    private(set) var attachCallCount = 0
    private let detachResult: Result<Void, ErrorInfo>?
    private(set) var detachCallCount = 0
    private(set) var releaseCallCount = 0
    private let _roomStatus: RoomStatus?
    private let _error: ErrorInfo?
    private let roomStatusSubscriptions = StatusSubscriptionStorage<RoomStatusChange>()
    private let discontinuitySubscriptions = StatusSubscriptionStorage<ErrorInfo>()
    private let resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ErrorInfo>?

    init(attachResult: Result<Void, ErrorInfo>? = nil, detachResult: Result<Void, ErrorInfo>? = nil, roomStatus: RoomStatus? = nil, error: ErrorInfo? = nil, resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ErrorInfo> = .success(())) {
        self.attachResult = attachResult
        self.detachResult = detachResult
        self.resultOfWaitToBeAbleToPerformPresenceOperations = resultOfWaitToBeAbleToPerformPresenceOperations
        _roomStatus = roomStatus
        _error = error
    }

    func performAttachOperation() async throws(ErrorInfo) {
        attachCallCount += 1
        guard let attachResult else {
            fatalError("In order to call performAttachOperation, attachResult must be passed to the initializer")
        }
        try attachResult.get()
    }

    func performDetachOperation() async throws(ErrorInfo) {
        detachCallCount += 1
        guard let detachResult else {
            fatalError("In order to call performDetachOperation, detachResult must be passed to the initializer")
        }
        try detachResult.get()
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

    var error: ErrorInfo? {
        _error
    }

    func emitStatusChange(_ statusChange: RoomStatusChange) {
        roomStatusSubscriptions.emit(statusChange)
    }

    func waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature) async throws(ErrorInfo) {
        guard let resultOfWaitToBeAbleToPerformPresenceOperations else {
            fatalError("resultOfWaitToBeAblePerformPresenceOperations must be set before waitToBeAbleToPerformPresenceOperations is called")
        }
        callRecorder.addRecord(
            signature: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "\(requestedByFeature)"],
        )
        try resultOfWaitToBeAbleToPerformPresenceOperations.get()
    }

    @discardableResult
    func onRoomStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> DefaultStatusSubscription {
        roomStatusSubscriptions.create(callback)
    }

    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> DefaultStatusSubscription {
        discontinuitySubscriptions.create(callback)
    }

    func emitDiscontinuity(_ error: ErrorInfo) {
        discontinuitySubscriptions.emit(error)
    }
}
