import Ably
@testable import AblyChat

final actor MockRealtimeChannel: InternalRealtimeChannelProtocol {
    let presence = MockRealtimePresence()

    private let attachSerial: String?
    private let channelSerial: String?
    private let _name: String?
    private let _state: ARTRealtimeChannelState?

    nonisolated var properties: ARTChannelProperties { .init(attachSerial: attachSerial, channelSerial: channelSerial) }

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
        state: ARTRealtimeChannelState? = nil,
        attachResult: AttachOrDetachResult? = nil,
        detachResult: AttachOrDetachResult? = nil,
        messageToEmitOnSubscribe: MessageToEmit? = nil
    ) {
        _name = name
        _state = state
        self.attachResult = attachResult
        self.detachResult = detachResult
        self.messageToEmitOnSubscribe = messageToEmitOnSubscribe
        attachSerial = properties.attachSerial
        channelSerial = properties.channelSerial
    }

    nonisolated var state: ARTRealtimeChannelState {
        guard let state = _state else {
            fatalError("Channel state not set")
        }
        return state
    }

    nonisolated var errorReason: ARTErrorInfo? {
        fatalError("Not implemented")
    }

    nonisolated var underlying: any RealtimeChannelProtocol {
        fatalError("Not implemented")
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

    private let attachResult: AttachOrDetachResult?

    var attachCallCount = 0

    func attach() async throws(InternalError) {
        attachCallCount += 1

        guard let attachResult else {
            fatalError("attachResult must be set before attach is called")
        }

        try attachResult.get()
    }

    private let detachResult: AttachOrDetachResult?

    var detachCallCount = 0

    func detach() async throws(InternalError) {
        detachCallCount += 1

        guard let detachResult else {
            fatalError("detachResult must be set before detach is called")
        }

        try detachResult.get()
    }

    let messageToEmitOnSubscribe: MessageToEmit?

    nonisolated func subscribe(_: String, callback: @escaping ARTMessageCallback) -> ARTEventListener? {
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

    nonisolated func unsubscribe(_: ARTEventListener?) {
        // no-op; revisit if we need to test something that depends on this method actually stopping `subscribe` from emitting more events
    }

    nonisolated func on(_: ARTChannelEvent, callback _: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        ARTEventListener()
    }

    nonisolated func on(_: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    nonisolated func off(_: ARTEventListener) {
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
