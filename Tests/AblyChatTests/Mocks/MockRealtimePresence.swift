import Ably
@testable import AblyChat

final class MockRealtimePresence: InternalRealtimePresenceProtocol {
    func subscribe(_: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func subscribe(_: ARTPresenceAction, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func unsubscribe(_: ARTEventListener) {
        fatalError("Not implemented")
    }

    func leaveClient(_: String, data _: JSONValue?) {
        fatalError("Not implemented")
    }

    func get() async throws(InternalError) -> [PresenceMessage] {
        fatalError("Not implemented")
    }

    func get(_: ARTRealtimePresenceQuery) async throws(InternalError) -> [PresenceMessage] {
        fatalError("Not implemented")
    }

    func leave(_: JSONValue?) async throws(InternalError) {
        fatalError("Not implemented")
    }

    func enterClient(_: String, data _: JSONValue?) async throws(InternalError) {
        fatalError("Not implemented")
    }

    func update(_: JSONValue?) async throws(InternalError) {
        fatalError("Not implemented")
    }
}
