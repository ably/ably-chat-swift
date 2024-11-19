import Ably

// TODO: Just copied chat-js implementation for now to send up agent info. https://github.com/ably-labs/ably-chat-swift/issues/76

// Update this when you release a new version
// Version information
internal let version = "0.1.0"

// Channel options agent string
internal let channelOptionsAgentString = "chat-ios/\(version)"

// Default channel options
internal var defaultChannelOptions: ARTRealtimeChannelOptions {
    let options = ARTRealtimeChannelOptions()
    options.params = ["agent": channelOptionsAgentString]
    return options
}
