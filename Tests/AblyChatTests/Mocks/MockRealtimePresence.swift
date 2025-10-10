import Ably
@testable import AblyChat

final class MockRealtimePresence: InternalRealtimePresenceProtocol {
    let callRecorder = MockMethodCallRecorder()

    func subscribe(_: @escaping @MainActor (ARTPresenceMessage) -> Void) -> ARTEventListener? {
        ARTEventListener()
    }

    func subscribe(_: ARTPresenceAction, callback _: @escaping @MainActor (ARTPresenceMessage) -> Void) -> ARTEventListener? {
        ARTEventListener()
    }

    func unsubscribe(_: ARTEventListener) {
        // no-op since it's called automatically
    }

    func get() async throws(InternalError) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get()",
            arguments: [:],
        )
        return []
    }

    func get(_ query: ARTRealtimePresenceQuery) async throws(InternalError) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get(_:)",
            arguments: ["query": "\(query.callRecorderDescription)"],
        )
        return []
    }

    func leave(_ data: JSONObject?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "leave(_:)",
            arguments: ["data": data],
        )
    }

    func enter(_ data: JSONObject?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "enter(_:)",
            arguments: ["data": data],
        )
    }

    func update(_ data: JSONObject?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "update(_:)",
            arguments: ["data": data],
        )
    }
}

extension ARTRealtimePresenceQuery {
    var callRecorderDescription: String {
        "clientId=\(clientId!)"
    }
}
