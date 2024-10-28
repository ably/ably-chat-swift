import Ably
import AblyChat

extension RoomStatus {
    var error: ARTErrorInfo? {
        switch self {
        case let .failed(error):
            error
        case let .suspended(error):
            error
        case .initialized,
             .attached,
             .attaching,
             .detached,
             .detaching,
             .releasing,
             .released:
            nil
        }
    }
}
