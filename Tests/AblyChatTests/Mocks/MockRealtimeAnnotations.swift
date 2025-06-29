import Ably
@testable import AblyChat

final class MockRealtimeAnnotations: InternalRealtimeAnnotationsProtocol {
    let annotationToEmitOnSubscribe: ARTAnnotation?

    init(annotationToEmitOnSubscribe: ARTAnnotation? = nil) {
        self.annotationToEmitOnSubscribe = annotationToEmitOnSubscribe
    }

    func subscribe(_ callback: @escaping @MainActor @Sendable (ARTAnnotation) -> Void) -> ARTEventListener? {
        subscribe("all", callback: callback) // "all" is arbitrary here, could be "". Due to `name` is not optional.
    }

    func subscribe(_: String, callback: @escaping @MainActor @Sendable (ARTAnnotation) -> Void) -> ARTEventListener? {
        if let annotation = annotationToEmitOnSubscribe {
            callback(annotation)
        }
        return ARTEventListener()
    }

    func unsubscribe(_: ARTEventListener) {
        fatalError("Not implemented")
    }
}
