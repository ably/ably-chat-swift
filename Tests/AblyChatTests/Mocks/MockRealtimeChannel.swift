import Ably
import AblyChat

final class MockRealtimeChannel: NSObject, RealtimeChannelProtocol {
    private let attachSerial: String?
    private let channelSerial: String?
    private let _name: String?
    private let mockPresence: MockRealtimePresence!

    private let _state: ARTRealtimeChannelState?

    var properties: ARTChannelProperties { .init(attachSerial: attachSerial, channelSerial: channelSerial) }

    var presence: some RealtimePresenceProtocol { mockPresence }

    // I don't see why the nonisolated(unsafe) keyword would cause a problem when used for tests in this context.
    nonisolated(unsafe) var lastMessagePublishedName: String?
    nonisolated(unsafe) var lastMessagePublishedData: Any?
    nonisolated(unsafe) var lastMessagePublishedExtras: (any ARTJsonCompatible)?

    typealias ARTChannelStateChangeCallback = (ARTChannelStateChange) -> Void

    private nonisolated(unsafe) var stateCallback: ARTChannelStateChangeCallback?
    private nonisolated(unsafe) var stateCallbacks = [ARTChannelEvent: ARTChannelStateChangeCallback]()

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
        messageToEmitOnSubscribe: MessageToEmit? = nil,
        messageJSONToEmitOnSubscribe: [String: Sendable]? = nil,
        mockPresence: MockRealtimePresence! = nil
    ) {
        _name = name
        _state = state
        self.attachResult = attachResult
        self.detachResult = detachResult
        self.messageToEmitOnSubscribe = messageToEmitOnSubscribe
        self.messageJSONToEmitOnSubscribe = messageJSONToEmitOnSubscribe
        attachSerial = properties.attachSerial
        channelSerial = properties.channelSerial
        self.mockPresence = mockPresence
    }

    /// A threadsafe counter that starts at zero.
    class Counter: @unchecked Sendable {
        private var mutex = NSLock()
        private var _value = 0

        var value: Int {
            let value: Int
            mutex.lock()
            value = _value
            mutex.unlock()
            return value
        }

        func increment() {
            mutex.lock()
            _value += 1
            mutex.unlock()
        }

        var isZero: Bool {
            value == 0
        }

        var isNonZero: Bool {
            value > 0
        }
    }

    var state: ARTRealtimeChannelState {
        if let _state {
            return _state
        }
        return attachResult == .success ? .attached : .failed
    }

    var errorReason: ARTErrorInfo? {
        fatalError("Not implemented")
    }

    var options: ARTRealtimeChannelOptions? {
        fatalError("Not implemented")
    }

    func attach() {
        attach(nil)
    }

    enum AttachOrDetachResult: Equatable {
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

    @MainActor
    func performStateChangeCallbacks(with stateChange: ARTChannelStateChange) {
        stateCallback?(stateChange)
        stateCallbacks[stateChange.event]?(stateChange)
    }

    @MainActor
    func performStateAttachCallbacks() {
        guard let attachResult else {
            fatalError("attachResult must be set before attach is called")
        }
        switch attachResult {
        case .success:
            performStateChangeCallbacks(with: ARTChannelStateChange(current: .attached, previous: .attaching, event: .attached, reason: nil))
        case let .failure(error):
            performStateChangeCallbacks(with: ARTChannelStateChange(current: .failed, previous: .attaching, event: .attached, reason: error))
        }
    }

    @MainActor
    func performStateDetachCallbacks() {
        guard let detachResult else {
            fatalError("attachResult must be set before attach is called")
        }
        switch detachResult {
        case .success:
            performStateChangeCallbacks(with: ARTChannelStateChange(current: .detached, previous: .detaching, event: .detached, reason: nil))
        case let .failure(error):
            performStateChangeCallbacks(with: ARTChannelStateChange(current: .failed, previous: .detaching, event: .detached, reason: error))
        }
    }

    private let attachResult: AttachOrDetachResult?

    let attachCallCounter = Counter()

    func attach(_ callback: ARTCallback?) {
        attachCallCounter.increment()

        guard let attachResult else {
            fatalError("attachResult must be set before attach is called")
        }

        attachResult.performCallback(callback)

        Task {
            await performStateAttachCallbacks()
        }
    }

    private let detachResult: AttachOrDetachResult?

    let detachCallCounter = Counter()

    func detach() {
        detach(nil)
    }

    func detach(_ callback: ARTCallback? = nil) {
        detachCallCounter.increment()

        guard let detachResult else {
            fatalError("detachResult must be set before detach is called")
        }

        detachResult.performCallback(callback)

        Task {
            await performStateDetachCallbacks()
        }
    }

    let messageToEmitOnSubscribe: MessageToEmit?
    let messageJSONToEmitOnSubscribe: [String: Sendable]?

    func subscribe(_: @escaping ARTMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func subscribe(attachCallback _: ARTCallback?, callback _: @escaping ARTMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func subscribe(_: String, callback: @escaping ARTMessageCallback) -> ARTEventListener? {
        if let json = messageJSONToEmitOnSubscribe {
            let message = ARTMessage(name: nil, data: json["data"] ?? "")
            if let action = json["action"] as? UInt {
                message.action = ARTMessageAction(rawValue: action) ?? .create
            }
            if let serial = json["serial"] as? String {
                message.serial = serial
            }
            if let clientId = json["clientId"] as? String {
                message.clientId = clientId
            }
            if let extras = json["extras"] as? ARTJsonCompatible {
                message.extras = extras
            }
            if let ts = json["timestamp"] as? String {
                message.timestamp = Date(timeIntervalSince1970: TimeInterval(ts)!)
            }
            callback(message)
        } else if let messageToEmitOnSubscribe {
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

    func subscribe(_: String, onAttach _: ARTCallback?, callback _: @escaping ARTMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func unsubscribe() {
        fatalError("Not implemented")
    }

    func unsubscribe(_: ARTEventListener?) {
        // no-op; revisit if we need to test something that depends on this method actually stopping `subscribe` from emitting more events
    }

    func unsubscribe(_: String, listener _: ARTEventListener?) {
        fatalError("Not implemented")
    }

    func history(_: ARTRealtimeHistoryQuery?, callback _: @escaping ARTPaginatedMessagesCallback) throws {
        fatalError("Not implemented")
    }

    func setOptions(_: ARTRealtimeChannelOptions?, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func on(_ event: ARTChannelEvent, callback: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        stateCallbacks[event] = callback
        return ARTEventListener()
    }

    func on(_ callback: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        stateCallback = callback
        return ARTEventListener()
    }

    func once(_: ARTChannelEvent, callback _: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func once(_: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func off(_: ARTChannelEvent, listener _: ARTEventListener) {
        fatalError("Not implemented")
    }

    func off(_: ARTEventListener) {
        // no-op; revisit if we need to test something that depends on this method actually stopping `on` from emitting more events
    }

    func off() {
        fatalError("Not implemented")
    }

    var name: String {
        guard let name = _name else {
            fatalError("Channel name not set")
        }
        return name
    }

    func publish(_: String?, data _: Any?) {
        fatalError("Not implemented")
    }

    func publish(_: String?, data _: Any?, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func publish(_: String?, data _: Any?, clientId _: String) {
        fatalError("Not implemented")
    }

    func publish(_: String?, data _: Any?, clientId _: String, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func publish(_ name: String?, data: Any?, extras: (any ARTJsonCompatible)?) {
        lastMessagePublishedName = name
        lastMessagePublishedExtras = extras
        lastMessagePublishedData = data
    }

    func publish(_: String?, data _: Any?, extras _: (any ARTJsonCompatible)?, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func publish(_: String?, data _: Any?, clientId _: String, extras _: (any ARTJsonCompatible)?) {
        fatalError("Not implemented")
    }

    func publish(_: String?, data _: Any?, clientId _: String, extras _: (any ARTJsonCompatible)?, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func publish(_: [ARTMessage]) {
        fatalError("Not implemented")
    }

    func publish(_: [ARTMessage], callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func history(_: @escaping ARTPaginatedMessagesCallback) {
        fatalError("Not implemented")
    }
}
