import Ably
@testable import AblyChat
import Testing

extension Tag {
    /// Any test that is not a unit test. This usually implies that it has a non-trivial execution time.
    @Tag static var integration: Self
}

/// Some very basic integration tests, just to check that things are kind of working.
///
/// It would be nice to give this a time limit, but unfortunately the `timeLimit` trait is only available on iOS 16 etc and above. CodeRabbit suggested writing a timeout function myself and wrapping the contents of the test in it, but I didn’t have time to try understanding its suggested code, so it can wait.
@Suite(.tags(.integration))
@MainActor
struct IntegrationTests {
    private class AblyCocoaLogger: ARTLog {
        private let label: String

        init(label: String) {
            self.label = label
        }

        override func log(_ message: String, with level: ARTLogLevel) {
            super.log("\(label): \(message)", with: level)
        }
    }

    private final class ChatLogger: LogHandler {
        private let label: String
        private let defaultLogHandler = DefaultLogHandler()

        init(label: String) {
            self.label = label
        }

        func log(message: String, level: LogLevel, context: LogContext?) {
            defaultLogHandler.log(message: "\(label): \(message)", level: level, context: context)
        }
    }

    private static func createSandboxRealtime(apiKey: String, loggingLabel: String) -> ARTRealtime {
        let realtimeOptions = ARTClientOptions(key: apiKey)
        realtimeOptions.environment = "sandbox"
        realtimeOptions.clientId = UUID().uuidString

        if TestLogger.loggingEnabled {
            realtimeOptions.logLevel = .verbose
            realtimeOptions.logHandler = AblyCocoaLogger(label: loggingLabel)
        }

        return ARTRealtime(options: realtimeOptions)
    }

    private static func createSandboxChatClient(apiKey: String, loggingLabel: String) -> DefaultChatClient {
        let realtime = createSandboxRealtime(apiKey: apiKey, loggingLabel: loggingLabel)
        let clientOptions = TestLogger.loggingEnabled ? ChatClientOptions(logHandler: ChatLogger(label: loggingLabel), logLevel: .trace) : nil

        return DefaultChatClient(realtime: realtime, clientOptions: clientOptions)
    }

    @Test
    func basicIntegrationTest() async throws {
        // MARK: - Setup + Attach

        let apiKey = try await Sandbox.createAPIKey()

        // (1) Create a couple of chat clients — one for sending and one for receiving
        let txClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "tx")
        let rxClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "rx")

        // (2) Fetch a room
        let roomID = "basketball"
        let txRoom = try await txClient.rooms.get(
            roomID: roomID,
            options: .init(
                presence: .init(),
                typing: .init(timeout: 2),
                reactions: .init(),
                occupancy: .init()
            )
        )
        let rxRoom = try await rxClient.rooms.get(
            roomID: roomID,
            options: .init(
                presence: .init(),
                typing: .init(timeout: 2),
                reactions: .init(),
                occupancy: .init()
            )
        )

        // (3) Subscribe to room status
        let rxRoomStatusSubscription = rxRoom.onStatusChange()

        // (4) Attach the room so we can receive messages on it
        try await rxRoom.attach()

        // (5) Check that we received an ATTACHED status change as a result of attaching the room
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .attached
        })
        #expect(rxRoom.status == .attached)

        // MARK: - Send and receive messages

        // (1) Send a message before subscribing to messages, so that later on we can check history works.

        // (2) Create a throwaway subscription and wait for it to receive a message. This is to make sure that rxRoom has seen the message that we send here, so that the first message we receive on the subscription created in (5) is that which we’ll send in (6), and not that which we send here.
        let throwawayRxMessageSubscription = try await rxRoom.messages.subscribe()

        // (3) Send the message
        let txMessageBeforeRxSubscribe = try await txRoom.messages.send(
            params: .init(
                text: "Hello from txRoom, before rxRoom subscribe"
            )
        )

        // (4) Wait for rxRoom to see the message we just sent
        let throwawayRxMessage = try #require(await throwawayRxMessageSubscription.first { @Sendable _ in true })
        #expect(throwawayRxMessage == txMessageBeforeRxSubscribe)

        // (5) Subscribe to messages
        let rxMessageSubscription = try await rxRoom.messages.subscribe()

        // (6) Now that we’re subscribed to messages, send a message on the other client and check that we receive it on the subscription
        let txMessageAfterRxSubscribe = try await txRoom.messages.send(
            params: .init(
                text: "Hello from txRoom, after rxRoom subscribe",
                metadata: ["someMetadataKey": 123, "someOtherMetadataKey": "foo"],
                headers: ["someHeadersKey": 456, "someOtherHeadersKey": "bar"]
            )
        )
        let rxMessageFromSubscription = try #require(await rxMessageSubscription.first { @Sendable _ in true })
        #expect(rxMessageFromSubscription == txMessageAfterRxSubscribe)

        // (7) Fetch historical messages from before subscribing, and check we get txMessageBeforeRxSubscribe

        /*
         TODO: This line should just be

         let messages = try await rxMessageSubscription.getPreviousMessages(params: .init())

         but sometimes `messages.items` is coming back empty. Andy said in
         https://ably-real-time.slack.com/archives/C03JDBVM5MY/p1733220395208909
         that

         > new materialised history system doesn’t currently support “live”
         > history (realtime implementation detail) - so we’re approximating the
         > behaviour

         and indicated that the right workaround for now is to introduce a
         wait. So we retry the fetching of history until we get a non-empty
         result.

         Revert this (https://github.com/ably/ably-chat-swift/issues/175) once it’s fixed in Realtime.
         */
        let rxMessagesBeforeSubscribing = try await {
            while true {
                let messages = try await rxMessageSubscription.getPreviousMessages(params: .init())
                if !messages.items.isEmpty {
                    return messages
                }
                // Wait 1 second before retrying the history fetch
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
        }()
        try #require(rxMessagesBeforeSubscribing.items.count == 1)
        #expect(rxMessagesBeforeSubscribing.items[0] == txMessageBeforeRxSubscribe)

        // MARK: - Editing and Deleting Messages

        // Reuse message subscription and message from (5) and (6) above
        let rxMessageEditDeleteSubscription = rxMessageSubscription
        let messageToEditDelete = txMessageAfterRxSubscribe

        // (1) Edit the message on the other client
        let txEditedMessage = try await txRoom.messages.update(
            newMessage: messageToEditDelete.copy(
                text: "edited message",
                metadata: ["someEditedKey": 123, "someOtherEditedKey": "foo"],
                headers: nil
            ),
            description: "random",
            metadata: nil
        )

        // (2) Check that we received the edited message on the subscription
        let rxEditedMessageFromSubscription = try #require(await rxMessageEditDeleteSubscription.first { @Sendable _ in true })

        // The createdAt varies by milliseconds so we can't compare the entire objects directly
        #expect(rxEditedMessageFromSubscription.roomID == txEditedMessage.roomID)
        #expect(rxEditedMessageFromSubscription.serial == txEditedMessage.serial)
        #expect(rxEditedMessageFromSubscription.clientID == txEditedMessage.clientID)
        #expect(rxEditedMessageFromSubscription.version == txEditedMessage.version)
        #expect(rxEditedMessageFromSubscription.id == txEditedMessage.id)
        #expect(rxEditedMessageFromSubscription.operation == txEditedMessage.operation)
        // Ensures text has been edited from original message
        #expect(rxEditedMessageFromSubscription.text == txEditedMessage.text)
        // Ensure headers are now null when compared to original message
        #expect(rxEditedMessageFromSubscription.headers == txEditedMessage.headers)
        // Ensures metadata has been updated from original message
        #expect(rxEditedMessageFromSubscription.metadata == txEditedMessage.metadata)

        // (3) Delete the message on the other client
        let txDeleteMessage = try await txRoom.messages.delete(
            message: rxEditedMessageFromSubscription,
            params: .init(
                description: "deleted in testing",
                metadata: nil // TODO: Setting as nil for now as a metadata with any non-string value causes a decoding error atm... https://github.com/ably/ably-chat-swift/issues/226
            )
        )

        // (4) Check that we received the deleted message on the subscription
        let rxDeletedMessageFromSubscription = try #require(await rxMessageEditDeleteSubscription.first { @Sendable _ in true })

        // The createdAt varies by milliseconds so we can't compare the entire objects directly
        #expect(rxDeletedMessageFromSubscription.roomID == txDeleteMessage.roomID)
        #expect(rxDeletedMessageFromSubscription.serial == txDeleteMessage.serial)
        #expect(rxDeletedMessageFromSubscription.clientID == txDeleteMessage.clientID)
        #expect(rxDeletedMessageFromSubscription.version == txDeleteMessage.version)
        #expect(rxDeletedMessageFromSubscription.id == txDeleteMessage.id)
        #expect(rxDeletedMessageFromSubscription.operation == txDeleteMessage.operation)
        #expect(rxDeletedMessageFromSubscription.text == txDeleteMessage.text)
        #expect(rxDeletedMessageFromSubscription.headers == txDeleteMessage.headers)
        #expect(rxDeletedMessageFromSubscription.metadata == txDeleteMessage.metadata)

        // MARK: - Reactions

        // (1) Subscribe to reactions
        let rxReactionSubscription = rxRoom.reactions.subscribe()

        // (2) Now that we’re subscribed to reactions, send a reaction on the other client and check that we receive it on the subscription
        try await txRoom.reactions.send(
            params: .init(
                type: "heart",
                metadata: ["someMetadataKey": 123, "someOtherMetadataKey": "foo"],
                headers: ["someHeadersKey": 456, "someOtherHeadersKey": "bar"]
            )
        )
        let rxReactionFromSubscription = try #require(await rxReactionSubscription.first { @Sendable _ in true })
        #expect(rxReactionFromSubscription.type == "heart")
        #expect(rxReactionFromSubscription.metadata == ["someMetadataKey": .number(123), "someOtherMetadataKey": .string("foo")])
        #expect(rxReactionFromSubscription.headers == ["someHeadersKey": .number(456), "someOtherHeadersKey": .string("bar")])

        // MARK: - Occupancy

        // It can take a moment for the occupancy to update from the clients connecting above, so we’ll wait a 2 seconds here.
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // (1) Get current occupancy
        let currentOccupancy = try await rxRoom.occupancy.get()
        #expect(currentOccupancy.connections != 0) // this flucuates dependant on the number of clients connected e.g. simulators running the test, hence why checking for non-zero
        #expect(currentOccupancy.presenceMembers == 0) // not yet entered presence

        // (2) Subscribe to occupancy
        let rxOccupancySubscription = rxRoom.occupancy.subscribe()

        // (3) Attach the room so we can perform presence operations
        try await txRoom.attach()

        // (4) Enter presence on the other client and check that we receive the updated occupancy on the subscription
        try await txRoom.presence.enter()

        // (5) Check that we received an updated presence count on the subscription
        _ = try #require(await rxOccupancySubscription.first { @Sendable occupancyEvent in
            occupancyEvent.presenceMembers == 1 // 1 for txClient entering presence
        })

        // (6) Check that we received an updated presence count when getting the occupancy
        let rxOccupancyAfterTxEnter = try await rxRoom.occupancy.get()
        #expect(rxOccupancyAfterTxEnter.presenceMembers == 1) // 1 for txClient entering presence

        // (7) Leave presence on the other client and check that we receive the updated occupancy on the subscription
        try await txRoom.presence.leave()

        // (8) Check that we received an updated presence count on the subscription
        _ = try #require(await rxOccupancySubscription.first { @Sendable occupancyEvent in
            occupancyEvent.presenceMembers == 0 // 0 for txClient leaving presence
        })

        // (9) Check that we received an updated presence count when getting the occupancy
        let rxOccupancyAfterTxLeave = try await rxRoom.occupancy.get()
        #expect(rxOccupancyAfterTxLeave.presenceMembers == 0) // 0 for txClient leaving presence

        // MARK: - Presence

        // (1) Subscribe to presence
        let rxPresenceSubscription = rxRoom.presence.subscribe(events: [.enter, .leave, .update])

        // (2) Send `.enter` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.enter(data: ["randomData": "randomValue"])
        let rxPresenceEnterTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceEnterTxEvent.action == .enter)
        #expect(rxPresenceEnterTxEvent.data == ["randomData": "randomValue"])

        // (3) Fetch rxClient's presence members and check that txClient is there
        let rxPresenceMembers = try await rxRoom.presence.get()
        #expect(rxPresenceMembers.count == 1)
        #expect(rxPresenceMembers[0].action == .present)
        #expect(rxPresenceMembers[0].data == ["randomData": "randomValue"])

        // (4) Send `.update` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.update(data: ["randomData": "randomValue"])
        let rxPresenceUpdateTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceUpdateTxEvent.action == .update)
        #expect(rxPresenceUpdateTxEvent.data == ["randomData": "randomValue"])

        // (5) Send `.leave` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.leave(data: ["randomData": "randomValue"])
        let rxPresenceLeaveTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceLeaveTxEvent.action == .leave)
        #expect(rxPresenceLeaveTxEvent.data == ["randomData": "randomValue"])

        // (6) Send `.enter` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.enter(data: ["randomData": "randomValue"])
        let rxPresenceEnterRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceEnterRxEvent.action == .enter)
        #expect(rxPresenceEnterRxEvent.data == ["randomData": "randomValue"])

        // (7) Send `.update` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.update(data: ["randomData": "randomValue"])
        let rxPresenceUpdateRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceUpdateRxEvent.action == .update)
        #expect(rxPresenceUpdateRxEvent.data == ["randomData": "randomValue"])

        // (8) Send `.leave` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.leave(data: ["randomData": "randomValue"])
        let rxPresenceLeaveRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        #expect(rxPresenceLeaveRxEvent.action == .leave)
        #expect(rxPresenceLeaveRxEvent.data == ["randomData": "randomValue"])

        // MARK: - Typing Indicators

        // (1) Subscribe to typing indicators
        let rxTypingSubscription = rxRoom.typing.subscribe()

        // (2) Start typing on txRoom and check that we receive the typing event on the subscription
        try await txRoom.typing.start()

        // (3) Wait for the typing event to be received
        var typingEvents: [TypingEvent] = []
        for await typingEvent in rxTypingSubscription {
            typingEvents.append(typingEvent)
            if typingEvents.count == 1 { break }
        }

        // (4) Check that we received the typing event showing that txRoom is typing
        #expect(typingEvents.count == 1)
        #expect(typingEvents[0].currentlyTyping.count == 1)

        // (5) Wait for the typing event to be received (auto sent from timeout)
        for await typingEvent in rxTypingSubscription {
            typingEvents.append(typingEvent)
            if typingEvents.count == 2 { break }
        }

        // (6) Check that we received the typing event showing that txRoom is no longer typing
        #expect(typingEvents.count == 2)
        #expect(typingEvents[1].currentlyTyping.isEmpty)

        // MARK: - Detach

        // (1) Detach the room
        try await rxRoom.detach()

        // (2) Check that we received a DETACHED status change as a result of detaching the room
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .detached
        })
        #expect(rxRoom.status == .detached)

        // MARK: - Release

        // (1) Release the room
        await rxClient.rooms.release(roomID: roomID)

        // (2) Check that we received a RELEASED status change as a result of releasing the room
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .released
        })
        #expect(rxRoom.status == .released)

        // (3) Fetch the room we just released and check it’s a new object
        let postReleaseRxRoom = try await rxClient.rooms.get(roomID: roomID, options: .init())
        #expect(postReleaseRxRoom !== rxRoom)
    }
}
