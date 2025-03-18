import Ably
@testable import AblyChat

final class MockRealtimeChannel: InternalRealtimeChannelProtocol {
    let presence = MockRealtimePresence()

    private let attachSerial: String?
    private let channelSerial: String?
    private let _name: String?

    nonisolated var properties: ARTChannelProperties { .init(attachSerial: attachSerial, channelSerial: channelSerial) }

    private var _state: ARTRealtimeChannelState?
    var errorReason: ARTErrorInfo?

    var lastMessagePublishedName: String?
    var lastMessagePublishedData: JSONValue?
    var lastMessagePublishedExtras: [String: JSONValue]?

    // TODO: If we tighten up the types we then we should be able to get rid of the `@unchecked Sendable` here, but I’m in a rush. Revisit in https://github.com/ably/ably-chat-swift/issues/195
    struct MessageToEmit: @unchecked Sendable {
        var action: ARTMessageAction
        var serial: String
        var clientID: String
        var data: Any
        var extras: NSDictionary
        var operation: ARTMessageOperation?
        var version: String
    }

    init(
        name: String? = nil,
        properties: ARTChannelProperties = .init(),
        initialState: ARTRealtimeChannelState? = nil,
        initialErrorReason: ARTErrorInfo? = nil,
        attachBehavior: AttachOrDetachBehavior? = nil,
        detachBehavior: AttachOrDetachBehavior? = nil,
        messageToEmitOnSubscribe: MessageToEmit? = nil,
        subscribeToStateBehavior: SubscribeToStateBehavior? = nil
    ) {
        _name = name
        _state = initialState
        self.attachBehavior = attachBehavior
        self.detachBehavior = detachBehavior
        errorReason = initialErrorReason
        self.messageToEmitOnSubscribe = messageToEmitOnSubscribe
        self.subscribeToStateBehavior = subscribeToStateBehavior ?? .justAddSubscription
        attachSerial = properties.attachSerial
        channelSerial = properties.channelSerial
    }

    var state: ARTRealtimeChannelState {
        guard let state = _state else {
            fatalError("Channel state not set")
        }
        return state
    }

    nonisolated var underlying: any RealtimeChannelProtocol {
        fatalError("Not implemented")
    }

    enum AttachOrDetachBehavior {
        /// Receives an argument indicating how many times (including the current call) the method for which this is providing a mock implementation has been called.
        case fromFunction(@Sendable (Int) async -> AttachOrDetachBehavior)
        case complete(AttachOrDetachResult)
        case completeAndChangeState(AttachOrDetachResult, newState: ARTRealtimeChannelState)

        static var success: Self {
            .complete(.success)
        }

        static func failure(_ error: ARTErrorInfo) -> Self {
            .complete(.failure(error))
        }
    }

    enum AttachOrDetachResult {
        case success
        case failure(ARTErrorInfo)

        func get() throws(InternalError) {
            switch self {
            case .success:
                break
            case let .failure(error):
                throw error.toInternalError()
            }
        }
    }

    private let attachBehavior: AttachOrDetachBehavior?

    var attachCallCount = 0

    func attach() async throws(InternalError) {
        attachCallCount += 1

        guard let attachBehavior else {
            fatalError("attachBehavior must be set before attach is called")
        }

        try await performBehavior(attachBehavior, callCount: attachCallCount)
    }

    private let detachBehavior: AttachOrDetachBehavior?

    var detachCallCount = 0

    func detach() async throws(InternalError) {
        detachCallCount += 1

        guard let detachBehavior else {
            fatalError("detachBehavior must be set before detach is called")
        }

        try await performBehavior(detachBehavior, callCount: detachCallCount)
    }

    private func performBehavior(_ behavior: AttachOrDetachBehavior, callCount: Int) async throws(InternalError) {
        let result: AttachOrDetachResult
        switch behavior {
        case let .fromFunction(function):
            let behavior = await function(callCount)
            try await performBehavior(behavior, callCount: callCount)
            return
        case let .complete(completeResult):
            result = completeResult
        case let .completeAndChangeState(completeResult, newState):
            _state = newState
            if case let .failure(error) = completeResult {
                errorReason = error
            }
            result = completeResult
        }

        try result.get()
    }

    let messageToEmitOnSubscribe: MessageToEmit?

    func subscribe(_: String, callback: @escaping @MainActor (ARTMessage) -> Void) -> ARTEventListener? {
        if let messageToEmitOnSubscribe {
            let message = ARTMessage(name: nil, data: messageToEmitOnSubscribe.data)
            message.action = messageToEmitOnSubscribe.action
            message.serial = messageToEmitOnSubscribe.serial
            message.clientId = messageToEmitOnSubscribe.clientID
            message.extras = messageToEmitOnSubscribe.extras
            message.operation = messageToEmitOnSubscribe.operation
            message.version = messageToEmitOnSubscribe.version
            callback(message)
        }
        return ARTEventListener()
    }

    func unsubscribe(_: ARTEventListener?) {
        // no-op; revisit if we need to test something that depends on this method actually stopping `subscribe` from emitting more events
    }

    enum SubscribeToStateBehavior {
        case justAddSubscription
        case addSubscriptionAndEmitStateChange(ARTChannelStateChange)
    }

    private let subscribeToStateBehavior: SubscribeToStateBehavior
    private var stateSubscriptionCallbacks: [@MainActor (ARTChannelStateChange) -> Void] = []

    func on(_: ARTChannelEvent, callback _: @escaping @MainActor (ARTChannelStateChange) -> Void) -> ARTEventListener {
        ARTEventListener()
    }

    func on(_ callback: @escaping @MainActor (ARTChannelStateChange) -> Void) -> ARTEventListener {
        stateSubscriptionCallbacks.append(callback)

        switch subscribeToStateBehavior {
        case .justAddSubscription:
            break
        case let .addSubscriptionAndEmitStateChange(stateChange):
            emitStateChange(stateChange)
        }

        return ARTEventListener()
    }

    func emitStateChange(_ stateChange: ARTChannelStateChange) {
        for callback in stateSubscriptionCallbacks {
            callback(stateChange)
        }
    }

    func off(_: ARTEventListener) {
        // no-op; revisit if we need to test something that depends on this method actually stopping `on` from emitting more events
    }

    nonisolated var name: String {
        guard let name = _name else {
            fatalError("Channel name not set")
        }
        return name
    }

    func publish(_ name: String?, data: JSONValue?, extras: [String: JSONValue]?) {
        lastMessagePublishedName = name
        lastMessagePublishedExtras = extras
        lastMessagePublishedData = data
    }
}
