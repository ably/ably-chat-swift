import Ably
@testable import AblyChat

/// `AsyncSequence` variant of `Room` status changes.
extension RoomLifecycleManager {
    func onRoomStatusChange(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<RoomStatusChange> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<RoomStatusChange>(bufferingPolicy: bufferingPolicy)

        let subscription = onRoomStatusChange { statusChange in
            subscriptionAsyncSequence.emit(statusChange)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }

    func onRoomStatusChange() -> SubscriptionAsyncSequence<RoomStatusChange> {
        onRoomStatusChange(bufferingPolicy: .unbounded)
    }

    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<ARTErrorInfo> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<ARTErrorInfo>(bufferingPolicy: bufferingPolicy)

        let subscription = onDiscontinuity { error in
            subscriptionAsyncSequence.emit(error)
        }
        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }
}

/// `AsyncSequence` variant of `DefaultRoomLifecycleManager` debug methods.
extension DefaultRoomLifecycleManager {
    func testsOnly_subscribeToOperationWaitEvents() -> SubscriptionAsyncSequence<OperationWaitEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<OperationWaitEvent>(bufferingPolicy: .unbounded)

        let subscription = testsOnly_subscribeToOperationWaitEvents { operationWaitEvent in
            subscriptionAsyncSequence.emit(operationWaitEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    func testsOnly_subscribeToStatusChangeWaitEvents() -> SubscriptionAsyncSequence<StatusChangeWaitEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<StatusChangeWaitEvent>(bufferingPolicy: .unbounded)

        let subscription = testsOnly_subscribeToStatusChangeWaitEvents { statusChangeWaitEvent in
            subscriptionAsyncSequence.emit(statusChangeWaitEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }
}

/// `AsyncSequence` variant of `DefaultRooms` debug methods.
extension DefaultRooms {
    func testsOnly_subscribeToOperationWaitEvents() -> SubscriptionAsyncSequence<OperationWaitEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<OperationWaitEvent>(bufferingPolicy: .unbounded)

        let subscription = testsOnly_subscribeToOperationWaitEvents { operationWaitEvent in
            subscriptionAsyncSequence.emit(operationWaitEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }
}
