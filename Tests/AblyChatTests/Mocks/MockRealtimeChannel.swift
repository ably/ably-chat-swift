import Ably
@testable import AblyChat

final class MockRealtimeChannel: InternalRealtimeChannelProtocol {
    let presence = MockRealtimePresence()

    private let attachSerial: String?
    private let channelSerial: String?
    private let _name: String?

    nonisolated var properties: ARTChannelProperties { .init(attachSerial: attachSerial, channelSerial: channelSerial) }

    private var _state: ARTRealtimeChannelState?
    private let stateChangeToEmitForListener: ARTChannelStateChange?
    var errorReason: ARTErrorInfo?

    var publishedMessages: [TestMessage] = []

    struct TestMessage {
        let name: String?
        let data: JSONValue?
        let extras: [String: JSONValue]?
    }

    init(
        name: String? = nil,
        properties: ARTChannelProperties = .init(),
        initialState: ARTRealtimeChannelState? = nil,
        initialErrorReason: ARTErrorInfo? = nil,
        attachBehavior: AttachOrDetachBehavior? = nil,
        detachBehavior: AttachOrDetachBehavior? = nil,
        messageJSONToEmitOnSubscribe: [String: JSONValue]? = nil,
        messageToEmitOnSubscribe: ARTMessage? = nil,
        stateChangeToEmitForListener: ARTChannelStateChange? = nil
    ) {
        _name = name
        _state = initialState
        self.attachBehavior = attachBehavior
        self.detachBehavior = detachBehavior
        errorReason = initialErrorReason
        self.messageJSONToEmitOnSubscribe = messageJSONToEmitOnSubscribe
        self.messageToEmitOnSubscribe = messageToEmitOnSubscribe
        attachSerial = properties.attachSerial
        channelSerial = properties.channelSerial
        self.stateChangeToEmitForListener = stateChangeToEmitForListener
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

    let messageJSONToEmitOnSubscribe: [String: JSONValue]?
    let messageToEmitOnSubscribe: ARTMessage?

    // Added the ability to emit a message whenever we want instead of just on subscribe... I didn't want to dig into what the messageToEmitOnSubscribe is too much so just if/else between the two.
    private var channelSubscriptions: [(String, (ARTMessage) -> Void)] = []

    func subscribe(_ name: String, callback: @escaping @MainActor (ARTMessage) -> Void) -> ARTEventListener? {
        if let json = messageJSONToEmitOnSubscribe {
            let message = ARTMessage(name: nil, data: json["data"]?.toAblyCocoaData ?? "")
            if let action = json["action"]?.numberValue as? UInt {
                message.action = ARTMessageAction(rawValue: action) ?? .create
            }
            if let serial = json["serial"]?.stringValue {
                message.serial = serial
            }
            if let clientId = json["clientId"]?.stringValue {
                message.clientId = clientId
            }
            if let extras = json["extras"]?.objectValue?.toARTJsonCompatible {
                message.extras = extras
            }
            if let ts = json["timestamp"]?.stringValue {
                message.timestamp = Date(timeIntervalSince1970: TimeInterval(ts)!)
            }
            callback(message)
        }
        if let messageToEmitOnSubscribe {
            Task {
                callback(messageToEmitOnSubscribe)
            }
        }
        channelSubscriptions.append((name, callback))
        return ARTEventListener()
    }

    func simulateIncomingMessage(_ with: ARTMessage, for name: String) {
        for (messageName, callback) in channelSubscriptions where messageName == name {
            callback(with)
        }
    }

    func unsubscribe(_: ARTEventListener?) {
        channelSubscriptions.removeAll() // make more strict when needed
    }

    private var stateSubscriptionCallbacks: [@MainActor (ARTChannelStateChange) -> Void] = []

    func on(_: ARTChannelEvent, callback: @escaping @MainActor (ARTChannelStateChange) -> Void) -> ARTEventListener {
        stateSubscriptionCallbacks.append(callback)
        return ARTEventListener()
    }

    func on(_ callback: @escaping @MainActor (ARTChannelStateChange) -> Void) -> ARTEventListener {
        stateSubscriptionCallbacks.append(callback)
        if let stateChangeToEmitForListener {
            callback(stateChangeToEmitForListener)
        }
        return ARTEventListener()
    }

    func emitEvent(_ event: ARTChannelStateChange) {
        for callback in stateSubscriptionCallbacks {
            callback(event)
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
        publishedMessages.append(TestMessage(name: name, data: data, extras: extras))
    }
}
