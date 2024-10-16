@testable import AblyChat
import Testing

struct MessageTests {
    let earlierMessage = Message(
        timeserial: "ABC123@1631840000000-5:2",
        clientID: "testClientID",
        roomID: "roomId",
        text: "hello",
        createdAt: nil,
        metadata: [:],
        headers: [:]
    )

    let laterMessage = Message(
        timeserial: "ABC123@1631840000001-5:2",
        clientID: "testClientID",
        roomID: "roomId",
        text: "hello",
        createdAt: nil,
        metadata: [:],
        headers: [:]
    )

    let invalidMessage = Message(
        timeserial: "invalid",
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
        #expect(try earlierMessage.isBefore(laterMessage))
    }

    // @specOneOf(2/3) CHA-M2a
    @Test
    func isBefore_WhenMessageIsNotBefore_ReturnsFalse() async throws {
        #expect(try !laterMessage.isBefore(earlierMessage))
    }

    // @specOneOf(3/3) CHA-M2a
    @Test
    func isBefore_whenTimeserialIsInvalid_throwsInvalidMessage() async throws {
        #expect(throws: DefaultTimeserial.TimeserialError.invalidFormat, performing: {
            try earlierMessage.isBefore(invalidMessage)
        })
    }

    // MARK: isAfter Tests

    // @specOneOf(1/3) CHA-M2b
    @Test
    func isAfter_whenMessageIsAfter_ReturnsTrue() async throws {
        #expect(try laterMessage.isAfter(earlierMessage))
    }

    // @specOneOf(2/3) CHA-M2b
    @Test
    func isAfter_whenMessageIsNotAfter_ReturnsFalse() async throws {
        #expect(try !earlierMessage.isAfter(laterMessage))
    }

    // @specOneOf(3/3) CHA-M2b
    @Test
    func isAfter_whenTimeserialIsInvalid_throwsInvalidMessage() async throws {
        #expect(throws: DefaultTimeserial.TimeserialError.invalidFormat, performing: {
            try earlierMessage.isAfter(invalidMessage)
        })
    }

    // MARK: isEqual Tests

    // @specOneOf(1/3) CHA-M2c
    @Test
    func isEqual_whenMessageIsEqual_ReturnsTrue() async throws {
        let duplicateOfEarlierMessage = Message(
            timeserial: "ABC123@1631840000000-5:2",
            clientID: "random",
            roomID: "",
            text: "",
            createdAt: nil,
            metadata: [:],
            headers: [:]
        )
        #expect(try earlierMessage.isEqual(duplicateOfEarlierMessage))
    }

    // @specOneOf(2/3) CHA-M2c
    @Test
    func isEqual_whenMessageIsNotEqual_ReturnsFalse() async throws {
        #expect(try !earlierMessage.isEqual(laterMessage))
    }

    // @specOneOf(3/3) CHA-M2c
    @Test
    func isEqual_whenTimeserialIsInvalid_throwsInvalidMessage() async throws {
        #expect(throws: DefaultTimeserial.TimeserialError.invalidFormat, performing: {
            try earlierMessage.isEqual(invalidMessage)
        })
    }
}
