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

    func leaveClient(_: String, data _: JSONValue?) {
        fatalError("Not implemented")
    }

    func get() async throws(InternalError) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get()",
            arguments: [:]
        )
        return []
    }

    func get(_ query: ARTRealtimePresenceQuery) async throws(InternalError) -> [PresenceMessage] {
        callRecorder.addRecord(
            signature: "get(_:)",
            arguments: ["query": "\(query.callRecorderDescription)"]
        )
        return []
    }

    func leave(_ data: JSONValue?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "leave(_:)",
            arguments: ["data": data]
        )
    }

    func enterClient(_ name: String, data: JSONValue?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "enterClient(_:data:)",
            arguments: ["name": name, "data": data]
        )
    }

    func update(_ data: JSONValue?) async throws(InternalError) {
        callRecorder.addRecord(
            signature: "update(_:)",
            arguments: ["data": data]
        )
    }
}

extension ARTRealtimePresenceQuery {
    var callRecorderDescription: String {
        "clientId=\(clientId!)"
    }
}

final class MockRealtimeAnnotations: InternalRealtimeAnnotationsProtocol {
    let annotationJSONToEmitOnSubscribe: [String: JSONValue]?

    init(annotationJSONToEmitOnSubscribe: [String: JSONValue]? = nil) {
        self.annotationJSONToEmitOnSubscribe = annotationJSONToEmitOnSubscribe
    }

    func getForMessage(_: AblyChat.Message, query _: ARTAnnotationsQuery) async throws(AblyChat.InternalError) -> any AblyChat.PaginatedResult<AblyChat.Annotation> {
        fatalError("Not implemented")
    }

    func getForMessageSerial(_: String, query _: ARTAnnotationsQuery) async throws(AblyChat.InternalError) -> any AblyChat.PaginatedResult<AblyChat.Annotation> {
        fatalError("Not implemented")
    }

    func subscribe(_ callback: @escaping @MainActor @Sendable (ARTAnnotation) -> Void) -> ARTEventListener? {
        subscribe("all", callback: callback)
    }

    func subscribe(_: String, callback: @escaping @MainActor @Sendable (ARTAnnotation) -> Void) -> ARTEventListener? {
        if let json = annotationJSONToEmitOnSubscribe {
            let annotation = ARTAnnotation()
            annotation.action = ARTAnnotationAction(rawValue: UInt(json["action"]?.numberValue ?? 0)) ?? .create
            if let serial = json["serial"]?.stringValue {
                annotation.serial = serial
            }
            if let messageSerial = json["messageSerial"]?.stringValue {
                annotation.messageSerial = messageSerial
            }
            if let clientId = json["clientId"]?.stringValue {
                annotation.clientId = clientId
            }
            if let type = json["type"]?.stringValue {
                annotation.type = type
            }
            if let name = json["name"]?.stringValue {
                annotation.name = name
            }
            if let count = json["count"]?.intValue {
                annotation.count = NSNumber(value: count)
            }
            if let extras = json["extras"]?.objectValue?.toARTJsonCompatible {
                annotation.extras = extras
            }
            if let ts = json["timestamp"]?.stringValue {
                annotation.timestamp = Date(timeIntervalSince1970: TimeInterval(ts)!)
            }
            callback(annotation)
        }
        return ARTEventListener()
    }

    func unsubscribe(_: ARTEventListener) {
        fatalError("Not implemented")
    }
}
