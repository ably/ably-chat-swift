@testable import AblyChat
import Testing

struct MessageTests {
    let earlierMessage = Message(
        serial: "ABC123@1631840000000-5:2",
        latestAction: .create,
        clientID: "testClientID",
        roomID: "roomId",
        text: "hello",
        createdAt: nil,
        metadata: [:],
        headers: [:]
    )

    let laterMessage = Message(
        serial: "ABC123@1631840000001-5:2",
        latestAction: .create,
        clientID: "testClientID",
        roomID: "roomId",
        text: "hello",
        createdAt: nil,
        metadata: [:],
        headers: [:]
    )

    let invalidMessage = Message(
        serial: "invalid",
        latestAction: .create,
        clientID: "testClientID",
        roomID: "roomId",
        text: "hello",
        createdAt: nil,
        metadata: [:],
        headers: [:]
    )

    // MARK: isBefore Tests

    // @specOneOf(1/3) CHA-M2a
    @Test
    func isBefore_WhenMessageIsBefore_ReturnsTrue() async throws {
        #expect(earlierMessage.serial < laterMessage.serial)
    }

    // @specOneOf(2/3) CHA-M2a
    @Test
    func isBefore_WhenMessageIsNotBefore_ReturnsFalse() async throws {
        #expect(laterMessage.serial > earlierMessage.serial)
    }

    // MARK: isAfter Tests

    // @specOneOf(1/3) CHA-M2b
    @Test
    func isAfter_whenMessageIsAfter_ReturnsTrue() async throws {
        #expect(laterMessage.serial > earlierMessage.serial)
    }

    // @specOneOf(2/3) CHA-M2b
    @Test
    func isAfter_whenMessageIsNotAfter_ReturnsFalse() async throws {
        #expect(earlierMessage.serial < laterMessage.serial)
    }

    // MARK: isEqual Tests

    // @specOneOf(1/3) CHA-M2c
    @Test
    func isEqual_whenMessageIsEqual_ReturnsTrue() async throws {
        let duplicateOfEarlierMessage = Message(
            serial: "ABC123@1631840000000-5:2",
            latestAction: .create,
            clientID: "random",
            roomID: "",
            text: "",
            createdAt: nil,
            metadata: [:],
            headers: [:]
        )
        #expect(earlierMessage.serial == duplicateOfEarlierMessage.serial)
    }

    // @specOneOf(2/3) CHA-M2c
    @Test
    func isEqual_whenMessageIsNotEqual_ReturnsFalse() async throws {
        #expect(earlierMessage.serial != laterMessage.serial)
    }
}
