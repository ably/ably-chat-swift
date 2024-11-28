// TODO: https://github.com/ably-labs/ably-chat-swift/issues/13 - try to improve this type
// I attempted to address this issue by making a struct conforming to Codable which would at least give us some safety in knowing items can be encoded and decoded. Gave up on it due to fixing other protocol requirements so gone for the same approach as Headers for now, we can investigate whether we need to be open to more types than this later.

public enum MetadataValue: Sendable, Codable, Equatable {
    case string(String)
    case number(Int) // Changed from NSNumber to Int to conform to Codable. Address in linked issue above.
    case bool(Bool)
    case null
}

/**
 * Metadata is a map of extra information that can be attached to chat
 * messages. It is not used by Ably and is sent as part of the realtime
 * message payload. Example use cases are setting custom styling like
 * background or text colors or fonts, adding links to external images,
 * emojis, etc.
 *
 * Do not use metadata for authoritative information. There is no server-side
 * validation. When reading the metadata treat it like user input.
 *
 */
public typealias Metadata = [String: MetadataValue?]
