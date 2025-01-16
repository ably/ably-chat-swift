import Ably
import AblyChat

final class MockRealtimePresence: RealtimePresenceProtocol {
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
