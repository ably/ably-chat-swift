@testable import AblyChat
import AblyPubSubDevice
import Foundation

// This mock isn't used much in the tests, since inside the SDK we mainly use `InternalRealtimeClientProtocol` (whose mock is ``MockRealtime``).
final class MockAblyCocoaRealtime: NSObject, RealtimeClientProtocol, @unchecked Sendable {
    let connection = Connection()
    let channels = Channels()

    var device: LocalDevice {
        fatalError("Not implemented")
    }

    var clientId: String? {
        fatalError("Not implemented")
    }

    override init() {}

    func time(_: @escaping DateTimeCallback) {
        fatalError("Not implemented")
    }

    func ping(_: @escaping Callback) {
        fatalError("Not implemented")
    }

    func stats(_: @escaping PaginatedStatsCallback) -> Bool {
        fatalError("Not implemented")
    }

    func stats(_: StatsQuery?, callback _: @escaping PaginatedStatsCallback) throws {
        fatalError("Not implemented")
    }

    func connect() {
        fatalError("Not implemented")
    }

    func close() {
        fatalError("Not implemented")
    }

    func request(_: String, path _: String, params _: [String: String]?, body _: Any?, headers _: [String: String]?, callback _: @escaping HTTPPaginatedCallback) throws {
        fatalError("Not implemented")
    }

    final class Channels: RealtimeChannelsProtocol {
        func get(_: String, options _: RealtimeChannelOptions) -> Channel {
            fatalError("Not implemented")
        }

        func exists(_: String) -> Bool {
            fatalError("Not implemented")
        }

        func release(_: String, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func release(_: String) {
            fatalError("Not implemented")
        }
    }

    final class Channel: RealtimeChannelProtocol {
        let presence = MockAblyCocoaRealtime.Presence()
        let annotations = MockAblyCocoaRealtime.Annotations()

        var state: RealtimeChannelState {
            fatalError("Not implemented")
        }

        var properties: ChannelProperties {
            fatalError("Not implemented")
        }

        var errorReason: AblyPubSubDevice.ErrorInfo? {
            fatalError("Not implemented")
        }

        var options: RealtimeChannelOptions? {
            fatalError("Not implemented")
        }

        func attach() {
            fatalError("Not implemented")
        }

        func attach(_: Callback? = nil) {
            fatalError("Not implemented")
        }

        func detach() {
            fatalError("Not implemented")
        }

        func detach(_: Callback? = nil) {
            fatalError("Not implemented")
        }

        func subscribe(_: @escaping MessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(attachCallback _: Callback?, callback _: @escaping MessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, callback _: @escaping MessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, onAttach _: Callback?, callback _: @escaping MessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: EventListener?) {
            fatalError("Not implemented")
        }

        func unsubscribe(_: String, listener _: EventListener?) {
            fatalError("Not implemented")
        }

        func history(_: RealtimeHistoryQuery?, callback _: @escaping PaginatedMessagesCallback) throws {
            fatalError("Not implemented")
        }

        func setOptions(_: RealtimeChannelOptions?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func on(_: ChannelEvent, callback _: @escaping (AblyPubSubDevice.ChannelStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func on(_: @escaping (AblyPubSubDevice.ChannelStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func once(_: ChannelEvent, callback _: @escaping (AblyPubSubDevice.ChannelStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func once(_: @escaping (AblyPubSubDevice.ChannelStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func off(_: ChannelEvent, listener _: EventListener) {
            fatalError("Not implemented")
        }

        func off(_: EventListener) {
            fatalError("Not implemented")
        }

        func off() {
            fatalError("Not implemented")
        }

        var name: String {
            fatalError("Not implemented")
        }

        var modes: ChannelMode {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, clientId _: String) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, clientId _: String, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, extras _: (any JsonCompatible)?) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, extras _: (any JsonCompatible)?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, clientId _: String, extras _: (any JsonCompatible)?) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, clientId _: String, extras _: (any JsonCompatible)?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func publish(_: [AblyPubSubDevice.Message]) {
            fatalError("Not implemented")
        }

        func publish(_: [AblyPubSubDevice.Message], callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func history(_: @escaping PaginatedMessagesCallback) {
            fatalError("Not implemented")
        }

        func publish(_: [AblyPubSubDevice.Message], resultCallback _: PublishResultCallback? = nil) {
            fatalError("Not implemented")
        }

        func publish(_: String?, data _: Any?, resultCallback _: PublishResultCallback? = nil) {
            fatalError("Not implemented")
        }

        func append(_: AblyPubSubDevice.Message, operation _: MessageOperation?, params _: [String: Stringifiable]?, callback _: EditResultCallback? = nil) {
            fatalError("Not implemented")
        }

        func update(_: AblyPubSubDevice.Message, operation _: MessageOperation?, params _: [String: Stringifiable]?, callback _: EditResultCallback? = nil) {
            fatalError("Not implemented")
        }

        func delete(_: AblyPubSubDevice.Message, operation _: MessageOperation?, params _: [String: Stringifiable]?, callback _: EditResultCallback? = nil) {
            fatalError("Not implemented")
        }

        func getMessageWithSerial(_: String, callback _: @escaping MessageErrorCallback) {
            fatalError("Not implemented")
        }

        func getMessageVersions(withSerial _: String, callback _: @escaping PaginatedMessagesCallback) {
            fatalError("Not implemented")
        }
    }

    final class Presence: RealtimePresenceProtocol {
        var syncComplete: Bool {
            fatalError("Not implemented")
        }

        func get(_: @escaping PresenceMessagesCallback) {
            fatalError("Not implemented")
        }

        func get(_: RealtimePresenceQuery, callback _: @escaping PresenceMessagesCallback) {
            fatalError("Not implemented")
        }

        func enter(_: Any?) {
            fatalError("Not implemented")
        }

        func enter(_: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func update(_: Any?) {
            fatalError("Not implemented")
        }

        func update(_: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func leave(_: Any?) {
            fatalError("Not implemented")
        }

        func leave(_: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func enterClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func enterClient(_: String, data _: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func updateClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func updateClient(_: String, data _: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func leaveClient(_: String, data _: Any?) {
            fatalError("Not implemented")
        }

        func leaveClient(_: String, data _: Any?, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func subscribe(_: @escaping PresenceMessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(attachCallback _: Callback?, callback _: @escaping PresenceMessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: PresenceAction, callback _: @escaping PresenceMessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: PresenceAction, onAttach _: Callback?, callback _: @escaping PresenceMessageCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: EventListener) {
            fatalError("Not implemented")
        }

        func unsubscribe(_: PresenceAction, listener _: EventListener) {
            fatalError("Not implemented")
        }

        func history(_: @escaping PaginatedPresenceCallback) {
            fatalError("Not implemented")
        }

        func history(_: RealtimeHistoryQuery?, callback _: @escaping PaginatedPresenceCallback) throws {
            fatalError("Not implemented")
        }
    }

    final class Annotations: RealtimeAnnotationsProtocol {
        func subscribe(_: @escaping AnnotationCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, callback _: @escaping AnnotationCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: EventListener) {
            fatalError("Not implemented")
        }

        func unsubscribe(_: String, listener _: EventListener) {
            fatalError("Not implemented")
        }

        func publish(for _: AblyPubSubDevice.Message, annotation _: OutboundAnnotation, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func publish(forMessageSerial _: String, annotation _: OutboundAnnotation, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func delete(for _: AblyPubSubDevice.Message, annotation _: OutboundAnnotation, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func delete(forMessageSerial _: String, annotation _: OutboundAnnotation, callback _: Callback? = nil) {
            fatalError("Not implemented")
        }

        func getFor(_: AblyPubSubDevice.Message, query _: AnnotationsQuery, callback _: @escaping PaginatedAnnotationsCallback) {
            fatalError("Not implemented")
        }

        func getForMessageSerial(_: String, query _: AnnotationsQuery, callback _: @escaping PaginatedAnnotationsCallback) {
            fatalError("Not implemented")
        }

        func subscribe(attachCallback _: Callback?, callback _: @escaping AnnotationCallback) -> EventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, onAttach _: Callback?, callback _: @escaping AnnotationCallback) -> EventListener? {
            fatalError("Not implemented")
        }
    }

    final class Connection: NSObject, CoreConnectionProtocol {
        var id: String? {
            fatalError("Not implemented")
        }

        var key: String? {
            fatalError("Not implemented")
        }

        var maxMessageSize: Int {
            fatalError("Not implemented")
        }

        var state: RealtimeConnectionState {
            fatalError("Not implemented")
        }

        var errorReason: AblyPubSubDevice.ErrorInfo? {
            fatalError("Not implemented")
        }

        var recoveryKey: String? {
            fatalError("Not implemented")
        }

        func createRecoveryKey() -> String? {
            fatalError("Not implemented")
        }

        func connect() {
            fatalError("Not implemented")
        }

        func close() {
            fatalError("Not implemented")
        }

        func ping(_: @escaping Callback) {
            fatalError("Not implemented")
        }

        func on(_: RealtimeConnectionEvent, callback _: @escaping (AblyPubSubDevice.ConnectionStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func on(_: @escaping (AblyPubSubDevice.ConnectionStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func once(_: RealtimeConnectionEvent, callback _: @escaping (AblyPubSubDevice.ConnectionStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func once(_: @escaping (AblyPubSubDevice.ConnectionStateChange) -> Void) -> EventListener {
            fatalError("Not implemented")
        }

        func off(_: RealtimeConnectionEvent, listener _: EventListener) {
            fatalError("Not implemented")
        }

        func off(_: EventListener) {
            fatalError("Not implemented")
        }

        func off() {
            fatalError("Not implemented")
        }
    }
}
