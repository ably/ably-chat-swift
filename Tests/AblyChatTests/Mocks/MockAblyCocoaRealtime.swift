import Ably
@testable import AblyChat
import Foundation

// This mock isn't used much in the tests, since inside the SDK we mainly use `InternalRealtimeClientProtocol` (whose mock is ``MockRealtime``).
final class MockAblyCocoaRealtime: NSObject, RealtimeClientProtocol, @unchecked Sendable {
    let connection = Connection()
    let channels = Channels()

    var device: ARTLocalDevice {
        fatalError("Not implemented")
    }

    var clientId: String? {
        fatalError("Not implemented")
    }

    override init() {}

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

    final class Channels: RealtimeChannelsProtocol {
        func get(_: String, options _: ARTRealtimeChannelOptions) -> Channel {
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
        let presence = MockAblyCocoaRealtime.Presence()
        let annotations = MockAblyCocoaRealtime.Annotations()

        var state: ARTRealtimeChannelState {
            fatalError("Not implemented")
        }

        var modes: ARTChannelMode {
            fatalError("Not implemented")
        }

        var properties: ARTChannelProperties {
            fatalError("Not implemented")
        }

        var errorReason: ARTErrorInfo? {
            fatalError("Not implemented")
        }

        var options: ARTRealtimeChannelOptions? {
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

    final class Presence: RealtimePresenceProtocol {
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

        func history(_: @escaping ARTPaginatedPresenceCallback) {
            fatalError("Not implemented")
        }

        func history(_: ARTRealtimeHistoryQuery?, callback _: @escaping ARTPaginatedPresenceCallback) throws {
            fatalError("Not implemented")
        }
    }

    final class Annotations: RealtimeAnnotationsProtocol {
        func publish(for _: ARTMessage, annotation _: ARTOutboundAnnotation, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func publish(forMessageSerial _: String, annotation _: ARTOutboundAnnotation, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func delete(for _: ARTMessage, annotation _: ARTOutboundAnnotation, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func delete(forMessageSerial _: String, annotation _: ARTOutboundAnnotation, callback _: ARTCallback? = nil) {
            fatalError("Not implemented")
        }

        func getFor(_: ARTMessage, query _: ARTAnnotationsQuery, callback _: @escaping ARTPaginatedAnnotationsCallback) {
            fatalError("Not implemented")
        }

        func getForMessageSerial(_: String, query _: ARTAnnotationsQuery, callback _: @escaping ARTPaginatedAnnotationsCallback) {
            fatalError("Not implemented")
        }

        func subscribe(_: @escaping ARTAnnotationCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func subscribe(_: String, callback _: @escaping ARTAnnotationCallback) -> ARTEventListener? {
            fatalError("Not implemented")
        }

        func unsubscribe() {
            fatalError("Not implemented")
        }

        func unsubscribe(_: ARTEventListener) {
            fatalError("Not implemented")
        }

        func unsubscribe(_: String, listener _: ARTEventListener) {
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

        var state: ARTRealtimeConnectionState {
            fatalError("Not implemented")
        }

        var errorReason: ARTErrorInfo? {
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
}
