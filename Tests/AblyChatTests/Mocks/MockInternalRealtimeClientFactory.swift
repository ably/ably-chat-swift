@testable import AblyChat
import Foundation

final class MockInternalRealtimeClientFactory: @unchecked Sendable, InternalRealtimeClientFactory {
    private let createInternalRealtimeClientReturnValue: any InternalRealtimeClientProtocol
    @SynchronizedAccess private(set) var createInternalRealtimeClientArgument: (any RealtimeClientProtocol)?

    init(createInternalRealtimeClientReturnValue: any InternalRealtimeClientProtocol) {
        self.createInternalRealtimeClientReturnValue = createInternalRealtimeClientReturnValue
    }

    func createInternalRealtimeClient(_ ablyCocoaRealtime: any RealtimeClientProtocol) -> any InternalRealtimeClientProtocol {
        createInternalRealtimeClientArgument = ablyCocoaRealtime
        return createInternalRealtimeClientReturnValue
    }
}
