import Ably

public protocol EmitsDiscontinuities {
    func subscribeToDiscontinuities() async -> Subscription<ARTErrorInfo?>
}
