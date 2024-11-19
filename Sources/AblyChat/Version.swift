import Ably

// TODO: Just copied chat-js implementation for now to send up agent info. https://github.com/ably-labs/ably-chat-swift/issues/76

// Update this when you release a new version
// Version information
internal let version = "0.1.0"

internal let channelOptionsAgentString = "chat-ios/\(version)"

internal let defaultChannelParams = ["agent": channelOptionsAgentString]
