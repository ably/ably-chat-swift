@testable import AblyChat
import AblyPubSubDevice

final class MockRealtimePresence: InternalRealtimePresenceProtocol {
    let callRecorder = MockMethodCallRecorder()

    func subscribe(_: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener? {
        EventListener()
    }

    func subscribe(_: PresenceAction, callback _: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener? {
        EventListener()
    }

    func unsubscribe(_: EventListener) {
        // no-op since it's called automatically
    }

    func get() async throws(ErrorInfo) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get()",
            arguments: [:],
        )
        return []
    }

    func get(_ query: RealtimePresenceQuery) async throws(ErrorInfo) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get(_:)",
            arguments: ["query": "\(query.callRecorderDescription)"],
        )
        return []
    }

    func leave(_ data: JSONObject?) async throws(ErrorInfo) {
        callRecorder.addRecord(
            signature: "leave(_:)",
            arguments: ["data": data],
        )
    }

    func enter(_ data: JSONObject?) async throws(ErrorInfo) {
        callRecorder.addRecord(
            signature: "enter(_:)",
            arguments: ["data": data],
        )
    }

    func update(_ data: JSONObject?) async throws(ErrorInfo) {
        callRecorder.addRecord(
            signature: "update(_:)",
            arguments: ["data": data],
        )
    }
}

extension RealtimePresenceQuery {
    var callRecorderDescription: String {
        "clientId=\(clientId!)"
    }
}
