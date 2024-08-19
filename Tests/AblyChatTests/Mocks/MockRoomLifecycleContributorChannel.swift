import Ably
@testable import AblyChat

final actor MockRoomLifecycleContributorChannel: RoomLifecycleContributorChannel {
    private let attachBehavior: AttachOrDetachBehavior?
    private let detachBehavior: AttachOrDetachBehavior?

    var state: ARTRealtimeChannelState
    var errorReason: ARTErrorInfo?

    private(set) var attachCallCount = 0
    private(set) var detachCallCount = 0

    init(
        initialState: ARTRealtimeChannelState,
        attachBehavior: AttachOrDetachBehavior?,
        detachBehavior: AttachOrDetachBehavior?
    ) {
        state = initialState
        self.attachBehavior = attachBehavior
        self.detachBehavior = detachBehavior
    }

    enum AttachOrDetachResult {
        case success
        case failure(ARTErrorInfo)

        func performCallback(_ callback: ARTCallback?) {
            switch self {
            case .success:
                callback?(nil)
            case let .failure(error):
                callback?(error)
            }
        }
    }

    enum AttachOrDetachBehavior {
        /// Receives an argument indicating how many times (including the current call) the method for which this is providing a mock implementation has been called.
        case fromFunction(@Sendable (Int) async -> AttachOrDetachResult)
        case complete(AttachOrDetachResult)
        case completeAndChangeState(AttachOrDetachResult, newState: ARTRealtimeChannelState)

        static var success: Self {
            .complete(.success)
        }

        static func failure(_ error: ARTErrorInfo) -> Self {
            .complete(.failure(error))
        }
    }

    func attach() async throws {
        attachCallCount += 1

        guard let attachBehavior else {
            fatalError("attachBehavior must be set before attach is called")
        }

        try await performBehavior(attachBehavior, callCount: attachCallCount)
    }

    func detach() async throws {
        detachCallCount += 1

        guard let detachBehavior else {
            fatalError("detachBehavior must be set before detach is called")
        }

        try await performBehavior(detachBehavior, callCount: detachCallCount)
    }

    private func performBehavior(_ behavior: AttachOrDetachBehavior, callCount: Int) async throws {
        let result: AttachOrDetachResult
        switch behavior {
        case let .fromFunction(function):
            result = await function(callCount)
        case let .complete(completeResult):
            result = completeResult
        case let .completeAndChangeState(completeResult, newState):
            state = newState
            if case let .failure(error) = completeResult {
                errorReason = error
            }
            result = completeResult
        }

        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }
}
