@testable import AblyChat
import AblyPubSubDevice

final class MockRealtimeAnnotations: InternalRealtimeAnnotationsProtocol {
    let annotationToEmitOnSubscribe: AblyPubSubDevice.Annotation?

    init(annotationToEmitOnSubscribe: AblyPubSubDevice.Annotation? = nil) {
        self.annotationToEmitOnSubscribe = annotationToEmitOnSubscribe
    }

    func subscribe(_ callback: @escaping @MainActor @Sendable (AblyPubSubDevice.Annotation) -> Void) -> EventListener? {
        subscribe("all", callback: callback) // "all" is arbitrary here, could be "". Due to `name` is not optional.
    }

    func subscribe(_: String, callback: @escaping @MainActor @Sendable (AblyPubSubDevice.Annotation) -> Void) -> EventListener? {
        if let annotation = annotationToEmitOnSubscribe {
            callback(annotation)
        }
        return EventListener()
    }

    func unsubscribe(_: EventListener) {
        fatalError("Not implemented")
    }
}
