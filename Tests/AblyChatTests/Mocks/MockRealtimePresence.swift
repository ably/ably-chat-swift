import Ably
import AblyChat

final class MockRealtimePresence: NSObject, RealtimePresenceProtocol {
    let callRecorder = MockMethodCallRecorder()

    let syncComplete: Bool

    init(syncComplete: Bool = true) {
        self.syncComplete = syncComplete
    }

    func get(_ callback: @escaping ARTPresenceMessagesCallback) {
        callRecorder.addRecord(signature: "\(#selector(Self.get(_:)))",
                               arguments: [:])
        callback([], nil)
    }

    func get(_ query: ARTRealtimePresenceQuery, callback: @escaping ARTPresenceMessagesCallback) {
        callRecorder.addRecord(signature: "\(#selector(Self.get(_:callback:)))",
                               arguments: ["query": "\(query)"])
        callback([], nil)
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

    func update(_ data: Any?, callback: ARTCallback?) {
        callRecorder.addRecord(signature: "\(#selector(Self.update(_:callback:)))",
                               arguments: ["data": data as Any])
        callback?(nil)
    }

    func leave(_: Any?) {
        fatalError("Not implemented")
    }

    func leave(_ data: Any?, callback: ARTCallback?) {
        callRecorder.addRecord(signature: "\(#selector(Self.leave(_:callback:)))",
                               arguments: ["data": data as Any])
        callback?(nil)
    }

    func enterClient(_: String, data _: Any?) {
        fatalError("Not implemented")
    }

    func enterClient(_ name: String, data: Any?, callback: ARTCallback? = nil) {
        callRecorder.addRecord(signature: "\(#selector(Self.enterClient(_:data:callback:)))",
                               arguments: ["name": name, "data": data as Any])
        callback?(nil)
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
        ARTEventListener()
    }

    func subscribe(_: ARTPresenceAction, onAttach _: ARTCallback?, callback _: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
        fatalError("Not implemented")
    }

    func unsubscribe() {
        fatalError("Not implemented")
    }

    func unsubscribe(_: ARTEventListener) {
        // no-op since it's called automatically
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

extension ARTRealtimePresenceQuery {
    override open var description: String {
        "clientId=\(clientId!)"
    }
}
