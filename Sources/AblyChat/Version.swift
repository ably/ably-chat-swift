import Ably

// TODO: Just copied chat-js implementation for now to send up agent info. https://github.com/ably-labs/ably-chat-swift/issues/76

// Update this when you release a new version
// Version information
internal let version = "0.1.2"

internal let channelOptionsAgentString = "chat-swift/\(version)"

internal let defaultChannelParams = ["agent": channelOptionsAgentString]
