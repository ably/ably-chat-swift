@testable import AblyChat

// AblyChat and AblyPubSubDevice both declare types under these names, so a
// bare reference in a test file is ambiguous. Declaring them here makes the
// bare name mean AblyChat's type, which is what the tests want in almost
// every case. A test that needs ably-cocoa's type spells it out in full, as
// `AblyPubSubDevice.Message`.

typealias Annotation = AblyChat.Annotation
typealias ChannelStateChange = AblyChat.ChannelStateChange
typealias ClientInformation = AblyChat.ClientInformation
typealias Connection = AblyChat.Connection
typealias ConnectionStateChange = AblyChat.ConnectionStateChange
typealias ErrorInfo = AblyChat.ErrorInfo
typealias LogLevel = AblyChat.LogLevel
typealias Message = AblyChat.Message
typealias MessageVersion = AblyChat.MessageVersion
typealias PaginatedResult = AblyChat.PaginatedResult
typealias Presence = AblyChat.Presence
typealias PresenceMessage = AblyChat.PresenceMessage
typealias RealtimeAnnotationsProtocol = AblyChat.RealtimeAnnotationsProtocol
typealias RealtimeChannelProtocol = AblyChat.RealtimeChannelProtocol
typealias RealtimeChannelsProtocol = AblyChat.RealtimeChannelsProtocol
typealias RealtimePresenceProtocol = AblyChat.RealtimePresenceProtocol
