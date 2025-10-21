@testable import Ably
@testable import AblyChat
import Foundation
import Testing

struct MessageTests {
    // MARK: - CHA-M11 (with message event)

    // @spec CHA-M11h - Created events must throw an error
    @Test
    func withChatMessageEventCreatedThrowsError() throws {
        // Given: An original message
        let originalTimestamp = Date(timeIntervalSince1970: 1000)
        let originalMessage = Message(
            serial: "msg-001",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-001", timestamp: originalTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: A created event for the same message
        let createdMessage = Message(
            serial: "msg-001",
            action: .messageCreate,
            clientID: "client-1",
            text: "Created text",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-001", timestamp: Date(timeIntervalSince1970: 2000)),
            timestamp: Date(timeIntervalSince1970: 2000),
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .created, message: createdMessage)

        // When/Then: Applying a created event should throw an error
        #expect(throws: ErrorInfo.self) {
            try originalMessage.with(messageEvent)
        }

        // Verify the error details
        do {
            _ = try originalMessage.with(messageEvent)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error.statusCode == 400)
            #expect(error.code == 40003)
        }
    }

    // @spec CHA-M11i - Error case: Event for a different message
    @Test
    func withChatMessageEventThrowsForDifferentMessage() throws {
        // Given: An original message
        let originalMessage = Message(
            serial: "msg-001",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text",
            metadata: [:],
            headers: [:],
            version: .init(serial: "msg-001", timestamp: Date()),
            timestamp: Date(),
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: An event for a different message (different serial)
        let differentMessage = Message(
            serial: "msg-002", // Different serial!
            action: .messageUpdate,
            clientID: "client-1",
            text: "Updated text",
            metadata: [:],
            headers: [:],
            version: .init(serial: "msg-002", timestamp: Date()),
            timestamp: Date(),
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .updated, message: differentMessage)

        // When/Then: Applying the event should throw an error
        #expect(throws: ErrorInfo.self) {
            try originalMessage.with(messageEvent)
        }

        // Verify the error is the correct type
        do {
            _ = try originalMessage.with(messageEvent)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error.statusCode == 400)
            #expect(error.code == 40003)
        }
    }

    // @spec CHA-M10e3 - Among Message instances of the same serial, the one with a lexicographically lower version.serial is older.
    // @specOneOf(1/2) CHA-M11c - Older or same age event returns original unchanged
    @Test
    func withChatMessageEventOlderReturnsOriginal() throws {
        // Given: An original message
        let originalTimestamp = Date(timeIntervalSince1970: 1000)
        let originalVersionTimestamp = Date(timeIntervalSince1970: 2000)
        let originalMessage = Message(
            serial: "msg-003",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-003@2", timestamp: originalVersionTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: An older update event (earlier version timestamp)
        let olderVersionTimestamp = Date(timeIntervalSince1970: 1500) // Older than 2000
        let olderMessage = Message(
            serial: "msg-003",
            action: .messageUpdate,
            clientID: "client-1",
            text: "Older updated text",
            metadata: ["oldKey": "oldValue"],
            headers: [:],
            version: .init(serial: "msg-003@1", timestamp: olderVersionTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .updated, message: olderMessage)

        // When: Applying the older event
        let result = try originalMessage.with(messageEvent)

        // Then: The original message should be returned unchanged (CHA-M11c)
        #expect(result.serial == originalMessage.serial)
        #expect(result.text == "Original text") // Original text, not "Older updated text"
        #expect(result.metadata == ["key": "value"]) // Original metadata
        #expect(result.version.serial == "msg-003@2") // Original version
        #expect(result.version.timestamp == originalVersionTimestamp)
    }

    // @spec CHA-M10e1 - Two Message instances of the same serial are considered the same version if they have the same version.serial property.
    // @specOneOf(2/2) CHA-M11c - Same age event returns original unchanged
    @Test
    func withChatMessageEventSameAgeReturnsOriginal() throws {
        // Given: An original message
        let originalTimestamp = Date(timeIntervalSince1970: 1000)
        let versionTimestamp = Date(timeIntervalSince1970: 2000)
        let originalMessage = Message(
            serial: "msg-004",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-004@1", timestamp: versionTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: An update event with the SAME version timestamp
        let sameMessage = Message(
            serial: "msg-004",
            action: .messageUpdate,
            clientID: "client-1",
            text: "Same age updated text",
            metadata: ["newKey": "newValue"],
            headers: [:],
            version: .init(serial: "msg-004@1", timestamp: versionTimestamp), // Same timestamp
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .updated, message: sameMessage)

        // When: Applying the same age event
        let result = try originalMessage.with(messageEvent)

        // Then: The original message should be returned unchanged (CHA-M11c)
        #expect(result.serial == originalMessage.serial)
        #expect(result.text == "Original text") // Original text
        #expect(result.metadata == ["key": "value"]) // Original metadata
        #expect(result.version.serial == "msg-004@1") // Original version
    }

    // @spec CHA-M10e2 - Among Message instances of the same serial, the one with a lexicographically higher version.serial is newer.
    // @specOneOf(1/2) CHA-M11d - Apply a newer update event
    @Test
    func withChatMessageEventUpdatedNewer() throws {
        // Given: An original message with reactions
        let originalTimestamp = Date(timeIntervalSince1970: 1000)
        let originalVersionTimestamp = Date(timeIntervalSince1970: 1500)
        let originalMessage = Message(
            serial: "msg-002",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-002", timestamp: originalVersionTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [
                    "like": .init(total: 3, clientIDs: ["user1", "user2", "user3"], clipped: false),
                ],
                multiple: [:],
            ),
        )

        // And: An updated event for the same message with a NEWER timestamp
        let updatedVersionTimestamp = Date(timeIntervalSince1970: 2000) // Newer than 1500
        let updatedMessage = Message(
            serial: "msg-002",
            action: .messageUpdate,
            clientID: "client-1",
            text: "Updated text",
            metadata: ["updatedKey": "updatedValue"],
            headers: ["updatedHeaderKey": "updatedHeaderValue"],
            version: .init(
                serial: "msg-002@v2",
                timestamp: updatedVersionTimestamp,
                clientID: "client-1",
                description: "Message was updated",
                metadata: ["updateReason": "typo fix"],
            ),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .updated, message: updatedMessage)

        // When: Applying the event
        let result = try originalMessage.with(messageEvent)

        // Then: The message should be updated with data from the event
        #expect(result.serial == "msg-002")
        #expect(result.action == .messageUpdate)
        #expect(result.text == "Updated text")
        #expect(result.metadata == ["updatedKey": "updatedValue"])
        #expect(result.headers == ["updatedHeaderKey": "updatedHeaderValue"])
        #expect(result.version.serial == "msg-002@v2")
        #expect(result.version.description == "Message was updated")

        // And: The reactions from the original message should be preserved (CHA-M11d)
        #expect(result.reactions.distinct["like"]?.total == 3)
    }

    // @specOneOf(2/2) CHA-M11d - Apply a newer delete event with reaction preservation
    @Test
    func withChatMessageEventDeleted() throws {
        // Given: An original message with reactions
        let originalTimestamp = Date(timeIntervalSince1970: 1000)
        let originalVersionTimestamp = Date(timeIntervalSince1970: 1500)
        let originalMessage = Message(
            serial: "msg-005",
            action: .messageCreate,
            clientID: "client-1",
            text: "Original text to be deleted",
            metadata: ["key": "value"],
            headers: ["headerKey": "headerValue"],
            version: .init(serial: "msg-005", timestamp: originalVersionTimestamp),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [
                    "sad": .init(total: 1, clientIDs: ["user1"], clipped: false),
                ],
                multiple: [:],
            ),
        )

        // And: A deleted event for the same message with a NEWER timestamp
        let deletedVersionTimestamp = Date(timeIntervalSince1970: 2000) // Newer than 1500
        let deletedMessage = Message(
            serial: "msg-005",
            action: .messageDelete,
            clientID: "client-1",
            text: "",
            metadata: [:],
            headers: [:],
            version: .init(
                serial: "msg-005@v3",
                timestamp: deletedVersionTimestamp,
                clientID: "client-1",
                description: "Message was deleted",
                metadata: ["deleteReason": "inappropriate"],
            ),
            timestamp: originalTimestamp,
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )
        let messageEvent = ChatMessageEvent(type: .deleted, message: deletedMessage)

        // When: Applying the event
        let result = try originalMessage.with(messageEvent)

        // Then: The message should be marked as deleted with data from the event
        #expect(result.serial == "msg-005")
        #expect(result.action == .messageDelete)
        #expect(result.text.isEmpty)
        #expect(result.metadata.isEmpty)
        #expect(result.headers.isEmpty)
        #expect(result.version.serial == "msg-005@v3")
        #expect(result.version.description == "Message was deleted")

        // And: The reactions from the original message should be preserved (CHA-M11d)
        #expect(result.reactions.distinct["sad"]?.total == 1)
    }

    // MARK: - CHA-M11 (with summary event)

    // @specOneOf(1/2) CHA-M11j - Apply a reaction summary event
    @Test
    func withMessageReactionSummaryEvent() throws {
        // Given: A message
        let message = Message(
            serial: "msg-001",
            action: .messageCreate,
            clientID: "client-1",
            text: "A message with reactions",
            metadata: [:],
            headers: [:],
            version: .init(serial: "msg-001", timestamp: Date()),
            timestamp: Date(),
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: A reaction summary event
        let reactionSummary = MessageReactionSummary(
            unique: [:],
            distinct: [
                "like": .init(total: 5, clientIDs: ["user1", "user2", "user3", "user4", "user5"], clipped: false),
                "love": .init(total: 2, clientIDs: ["user1", "user6"], clipped: false),
            ],
            multiple: [:],
        )
        let summaryEvent = MessageReactionSummaryEvent(type: .summary, messageSerial: "msg-001", reactions: reactionSummary)

        // When: Applying the event
        let updatedMessage = try message.with(summaryEvent)

        // Then: The message should have the reaction summary
        #expect(updatedMessage.reactions.distinct.count == 2)
        #expect(updatedMessage.reactions.distinct["like"]?.total == 5)
        #expect(updatedMessage.reactions.distinct["love"]?.total == 2)
    }

    // @specOneOf(2/2) CHA-M11j - Error case: Summary event for a different message
    @Test
    func withMessageReactionSummaryEventThrowsForDifferentMessage() throws {
        // Given: A message
        let message = Message(
            serial: "msg-001",
            action: .messageCreate,
            clientID: "client-1",
            text: "A message",
            metadata: [:],
            headers: [:],
            version: .init(serial: "msg-001", timestamp: Date()),
            timestamp: Date(),
            reactions: MessageReactionSummary(
                unique: [:],
                distinct: [:],
                multiple: [:],
            ),
        )

        // And: A reaction summary event for a different message
        let reactionSummary = MessageReactionSummary(
            unique: [:],
            distinct: [
                "like": .init(total: 1, clientIDs: ["user1"], clipped: false),
            ],
            multiple: [:],
        )
        let summaryEvent = MessageReactionSummaryEvent(type: .summary, messageSerial: "msg-002", reactions: reactionSummary)

        // When/Then: Applying the event should throw an error
        #expect(throws: ErrorInfo.self) {
            try message.with(summaryEvent)
        }

        // Verify the error is the correct type
        do {
            _ = try message.with(summaryEvent)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error.statusCode == 400)
            #expect(error.code == 40003)
        }
    }
}
