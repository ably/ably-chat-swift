import Foundation

public typealias MessageHeaders = Headers
public typealias MessageMetadata = Metadata

// (CHA-M2) A Message corresponds to a single message in a chat room. This is analogous to a single user-specified message on an Ably channel (NOTE: not a ProtocolMessage).
public struct Message: Sendable, Codable, Identifiable, Equatable {
    // id to meet Identifiable conformance. 2 messages in the same channel cannot have the same serial.
    public var id: String { serial }

    public var serial: String
    public var action: MessageAction
    public var clientID: String
    public var roomID: String
    public var text: String
    public var createdAt: Date?
    public var metadata: MessageMetadata
    public var headers: MessageHeaders

    public init(serial: String, action: MessageAction, clientID: String, roomID: String, text: String, createdAt: Date?, metadata: MessageMetadata, headers: MessageHeaders) {
        self.serial = serial
        self.action = action
        self.clientID = clientID
        self.roomID = roomID
        self.text = text
        self.createdAt = createdAt
        self.metadata = metadata
        self.headers = headers
    }

    internal enum CodingKeys: String, CodingKey {
        case serial
        case action
        case clientID = "clientId"
        case roomID = "roomId"
        case text
        case createdAt
        case metadata
        case headers
    }
}
