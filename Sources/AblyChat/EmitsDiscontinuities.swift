import Ably

public protocol EmitsDiscontinuities {
    func subscribeToDiscontinuities() -> Subscription<ARTErrorInfo>
}
