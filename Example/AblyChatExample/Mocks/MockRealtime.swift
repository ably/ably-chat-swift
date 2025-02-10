import Ably
import AblyChat

/// A mock implementation of `RealtimeClientProtocol`. It only exists so that we can construct an instance of `DefaultChatClient` without needing to create a proper `ARTRealtime` instance (which we can’t yet do because we don’t have a method for inserting an API key into the example app). TODO remove this once we start building the example app
final class MockRealtime: NSObject, RealtimeClientProtocol, Sendable {
    let connection = Connection()

    var device: ARTLocalDevice {
        fatalError("Not implemented")
    }

    var clientId: String? {
        fatalError("Not implemented")
    }

    let channels = Channels()

    final class Connection: NSObject, ConnectionProtocol {
        init(id: String? = nil, key: String? = nil, maxMessageSize: Int = 0, state: ARTRealtimeConnectionState = .closed, errorReason: ARTErrorInfo? = nil, recoveryKey: String? = nil) {
            self.id = id
            self.key = key
            self.maxMessageSize = maxMessageSize
            self.state = state
            self.errorReason = errorReason
            self.recoveryKey = recoveryKey
        }

        let id: String?

        let key: String?

        let maxMessageSize: Int

        let state: ARTRealtimeConnectionState

        let errorReason: ARTErrorInfo?

        let recoveryKey: String?

        func createRecoveryKey() -> String? {
            fatalError("Not implemented")
        }

        func connect() {
            fatalError("Not implemented")
        }

        func close() {
            fatalError("Not implemented")
        }

        func ping(_: @escaping ARTCallback) {
            fatalError("Not implemented")
        }

        func on(_: ARTRealtimeConnectionEvent, callback _: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
        }

        func on(_: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
        }

        func once(_: ARTRealtimeConnectionEvent, callback _: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
        }

        func once(_: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
        }

        func off(_: ARTRealtimeConnectionEvent, listener _: ARTEventListener) {
            fatalError("Not implemented")
        }

        func off(_: ARTEventListener) {
            fatalError("Not implemented")
        }

        func off() {
            fatalError("Not implemented")
        }
    }

    final class Channels: RealtimeChannelsProtocol {
        func get(_: String, options _: ARTRealtimeChannelOptions) -> MockRealtime.Channel {
            fatalError("Not implemented")
        }

        func exists(_: String) -> Bool {
            fatalError("Not implemented")
        }

        func release(_: String, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func release(_: String) {
            fatalError("Not implemented")
        }
    }

    final class Channel: RealtimeChannelProtocol {
        var state: ARTRealtimeChannelState {
            fatalError("Not implemented")
        }

        let presence = RealtimePresence()

        var errorReason: ARTErrorInfo? {
            fatalError("Not implemented")
        }

        var options: ARTRealtimeChannelOptions? {
            fatalError("Not implemented")
        }

        var properties: ARTChannelProperties {
            fatalError("Not implemented")
        }

        func attach() {
            fatalError("Not implemented")
        }

        func attach(_: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func detach() {
            fatalError("Not implemented")
        }

        func detach(_: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func subscribe(_: @escaping ARTMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(attachCallback _: ARTCallback?, callback _: @escaping ARTMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, callback _: @escaping ARTMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, onAttach _: ARTCallback?, callback _: @escaping ARTMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: ARTEventListener?) {
            fatalError("Not implemented")
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

        func on(_: ARTChannelEvent, callback _: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
        }

        func on(_: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
            fatalError("Not implemented")
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
            fatalError("Not implemented")
        }

        func off() {
            fatalError("Not implemented")
        }

        var name: String {
            fatalError("Not implemented")
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

        func publish(_: String?, data _: Any?, extras _: (any ARTJsonCompatible)?) {
            fatalError("Not implemented")
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

    final class RealtimePresence: RealtimePresenceProtocol {
        var syncComplete: Bool {
            fatalError("Not implemented")
        }

        func get(_: @escaping ARTPresenceMessagesCallback) {
            fatalError("Not implemented")
        }

        func get(_: ARTRealtimePresenceQuery, callback _: @escaping ARTPresenceMessagesCallback) {
            fatalError("Not implemented")
        }

        func enter(_: Any?) {
            fatalError("Not implemented")
        }

        func enter(_: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func update(_: Any?) {
            fatalError("Not implemented")
        }

        func update(_: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func leave(_: Any?) {
            fatalError("Not implemented")
        }

        func leave(_: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func enterClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func enterClient(_: String, data _: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func updateClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func updateClient(_: String, data _: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func leaveClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func leaveClient(_: String, data _: Any?, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func subscribe(_: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(attachCallback _: ARTCallback?, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: ARTPresenceAction, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: ARTPresenceAction, onAttach _: ARTCallback?, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: ARTEventListener) {
            fatalError("Not implemented")
        }

        func unsubscribe(_: ARTPresenceAction, listener _: ARTEventListener) {
            fatalError("Not implemented")
        }

        func history(_: @escaping ARTPaginatedPresenceCallback) {}

        func history(_: ARTRealtimeHistoryQuery?, callback _: @escaping ARTPaginatedPresenceCallback) throws {
            fatalError("Not implemented")
        }
    }

    func time(_: @escaping ARTDateTimeCallback) {
        fatalError("Not implemented")
    }

    func ping(_: @escaping ARTCallback) {
        fatalError("Not implemented")
    }

    func stats(_: @escaping ARTPaginatedStatsCallback) -> Bool {
        fatalError("Not implemented")
    }

    func stats(_: ARTStatsQuery?, callback _: @escaping ARTPaginatedStatsCallback) throws {
        fatalError("Not implemented")
    }

    func connect() {
        fatalError("Not implemented")
    }

    func close() {
        fatalError("Not implemented")
    }

    func request(_: String, path _: String, params _: [String: String]?, body _: Any?, headers _: [String: String]?, callback _: @escaping ARTHTTPPaginatedCallback) throws {
        fatalError("Not implemented")
    }
}
