import Ably

/// Information about the Chat SDK.
internal enum ClientInformation {
    /// The version number of this version of the Chat SDK.
    internal static let version = "1.0.1"

    /// The agents to pass to `createWrapperSDKProxy` per CHA-IN1b.
    internal static let agents = ["chat-swift": Self.version]
}
