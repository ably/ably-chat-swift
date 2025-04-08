@testable import AblyChat
import Foundation

final class MockInternalRealtimeClientFactory: InternalRealtimeClientFactory {
    private let createInternalRealtimeClientReturnValue: any InternalRealtimeClientProtocol
    private(set) var createInternalRealtimeClientArgument: (any RealtimeClientProtocol)?

    init(createInternalRealtimeClientReturnValue: any InternalRealtimeClientProtocol) {
        self.createInternalRealtimeClientReturnValue = createInternalRealtimeClientReturnValue
    }

    func createInternalRealtimeClient(_ ablyCocoaRealtime: any RealtimeClientProtocol) -> any InternalRealtimeClientProtocol {
        createInternalRealtimeClientArgument = ablyCocoaRealtime
        return createInternalRealtimeClientReturnValue
    }
}
