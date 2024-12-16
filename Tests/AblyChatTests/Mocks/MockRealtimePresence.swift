import Ably
import AblyChat

final class MockRealtimePresence: NSObject, @unchecked Sendable, RealtimePresenceProtocol {
    let syncComplete: Bool
    private var members: [ARTPresenceMessage]

    init(syncComplete: Bool = true, _ members: [ARTPresenceMessage]) {
        self.syncComplete = syncComplete
        self.members = members
    }

    func get(_ callback: @escaping ARTPresenceMessagesCallback) {
        callback(members, nil)
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

    func enterClient(_ clientId: String, data _: Any?) {
        members.append(ARTPresenceMessage(clientId: clientId))
    }

    func enterClient(_ clientId: String, data _: Any?, callback: ARTCallback? = nil) {
        members.append(ARTPresenceMessage(clientId: clientId))
        callback?(nil)
    }

    func updateClient(_: String, data _: Any?) {
        fatalError("Not implemented")
    }

    func updateClient(_: String, data _: Any?, callback _: ARTCallback? = nil) {
        fatalError("Not implemented")
    }

    func leaveClient(_ clientId: String, data _: Any?) {
        members.removeAll { $0.clientId == clientId }
    }

    func leaveClient(_ clientId: String, data _: Any?, callback _: ARTCallback? = nil) {
        members.removeAll { $0.clientId == clientId }
    }

    func subscribe(_: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        ARTEventListener()
    }

    func subscribe(attachCallback _: ARTCallback?, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        ARTEventListener()
    }

    func subscribe(_: ARTPresenceAction, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        ARTEventListener()
    }

    func subscribe(_: ARTPresenceAction, onAttach _: ARTCallback?, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        ARTEventListener()
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
