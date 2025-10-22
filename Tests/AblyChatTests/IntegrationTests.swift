// MAINTAINER NOTE: This file includes extensive logging before and after every
// `await` call to help debug hanging tests in CI as part of
// https://github.com/ably/ably-chat-swift/issues/295. While we investigate and
// fix the root cause of these hangs, please maintain this logging pattern when
// adding new integration tests or modifying existing ones. Use
// `Self.logAwait("description")` before and after each await point. The
// logging includes timestamps and function names to help identify where hangs
// occur.

import Ably
@testable import AblyChat
import Testing

extension Tag {
    /// Any test that is not a unit test. This usually implies that it has a non-trivial execution time.
    @Tag static var integration: Self
}

/// Some very basic integration tests, just to check that things are kind of working.
///
/// It would be nice to give this a time limit, but unfortunately the `timeLimit` trait is only available on iOS 16 etc and above. CodeRabbit suggested writing a timeout function myself and wrapping the contents of the test in it, but I didn't have time to try understanding its suggested code, so it can wait.
@Suite(.tags(.integration))
@MainActor
struct IntegrationTests {
    /// Helper for logging await points with timestamps to debug hanging tests
    private static func logAwait(_ message: String, function: String = #function, file: String = #fileID, line: Int = #line) {
        let timestamp = Date().timeIntervalSince1970
        print("[\(timestamp)] [await] \(function) \(file):\(line) - \(message)")
    }

    private class AblyCocoaLogger: ARTLog {
        private let label: String

        init(label: String) {
            self.label = label
        }

        override func log(_ message: String, with level: ARTLogLevel) {
            super.log("\(label): \(message)", with: level)
        }
    }

    private final class ChatLogger: LogHandler.Simple {
        private let label: String
        private let defaultLogHandler = DefaultSimpleLogHandler()

        init(label: String) {
            self.label = label
        }

        func log(message: String, level: LogLevel) {
            defaultLogHandler.log(message: "\(label): \(message)", level: level)
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

    private static func createSandboxChatClient(apiKey: String, loggingLabel: String) -> ChatClient {
        let realtime = createSandboxRealtime(apiKey: apiKey, loggingLabel: loggingLabel)
        let clientOptions = TestLogger.loggingEnabled ? ChatClientOptions(logHandler: .simple(ChatLogger(label: loggingLabel)), logLevel: .trace) : nil

        return ChatClient(realtime: realtime, clientOptions: clientOptions)
    }

    @Test
    func basicIntegrationTest() async throws {
        // MARK: - Setup + Attach

        Self.logAwait("BEFORE Sandbox.createAPIKey()")
        let apiKey = try await Sandbox.createAPIKey()
        Self.logAwait("AFTER Sandbox.createAPIKey()")

        // (1) Create a couple of chat clients — one for sending and one for receiving
        let txClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "tx")
        let txClientID = try #require(txClient.clientID)
        let rxClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "rx")

        // (2) Fetch a room
        let roomName = "basketball"
        Self.logAwait("BEFORE txClient.rooms.get()")
        let txRoom = try await txClient.rooms.get(
            named: roomName,
            options: .init(
                presence: .init(),
                typing: .init(heartbeatThrottle: 2),
                occupancy: .init(),
            ),
        )
        Self.logAwait("AFTER txClient.rooms.get()")
        Self.logAwait("BEFORE rxClient.rooms.get()")
        let rxRoom = try await rxClient.rooms.get(
            named: roomName,
            options: .init(
                messages: .init(rawMessageReactions: true),
                presence: .init(),
                typing: .init(heartbeatThrottle: 2),
                occupancy: .init(enableEvents: true),
            ),
        )
        Self.logAwait("AFTER rxClient.rooms.get()")

        // (3) Subscribe to room status
        let rxRoomStatusSubscription = rxRoom.onStatusChange()

        // (4) Attach the room so we can receive messages on it
        Self.logAwait("BEFORE rxRoom.attach()")
        try await rxRoom.attach()
        Self.logAwait("AFTER rxRoom.attach()")

        // (5) Check that we received an ATTACHED status change as a result of attaching the room
        Self.logAwait("BEFORE rxRoomStatusSubscription.first (ATTACHED)")
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .attached
        })
        Self.logAwait("AFTER rxRoomStatusSubscription.first (ATTACHED)")
        #expect(rxRoom.status == .attached)

        // MARK: - Send and receive messages

        // (1) Send a message before subscribing to messages, so that later on we can check history works.

        // (2) Create a throwaway subscription and wait for it to receive a message. This is to make sure that rxRoom has seen the message that we send here, so that the first message we receive on the subscription created in (5) is that which we'll send in (6), and not that which we send here.
        let throwawayRxMessageSubscription = rxRoom.messages.subscribe()

        // (3) Send the message
        Self.logAwait("BEFORE txRoom.messages.send (before subscribe)")
        let txMessageBeforeRxSubscribe = try await txRoom.messages.send(
            withParams: .init(
                text: "Hello from txRoom, before rxRoom subscribe",
                metadata: ["someMetadataKey": 123, "someOtherMetadataKey": "foo"],
                headers: ["someHeadersKey": 456, "someOtherHeadersKey": "bar"],
            ),
        )
        Self.logAwait("AFTER txRoom.messages.send (before subscribe)")

        // (4) Wait for rxRoom to see the message we just sent
        Self.logAwait("BEFORE throwawayRxMessageSubscription.first")
        let throwawayRxEvent = try #require(await throwawayRxMessageSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER throwawayRxMessageSubscription.first")
        #expect(areMessagesEqualModuloNonSerialVersionInfo(throwawayRxEvent.message, txMessageBeforeRxSubscribe))

        // (5) Subscribe to messages
        let rxMessageSubscription = rxRoom.messages.subscribe()

        // (6) Now that we're subscribed to messages, send a message on the other client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.messages.send (after subscribe)")
        let txMessageAfterRxSubscribe = try await txRoom.messages.send(
            withParams: .init(
                text: "Hello from txRoom, after rxRoom subscribe",
                metadata: ["someMetadataKey": 123, "someOtherMetadataKey": "foo"],
                headers: ["someHeadersKey": 456, "someOtherHeadersKey": "bar"],
            ),
        )
        Self.logAwait("AFTER txRoom.messages.send (after subscribe)")
        Self.logAwait("BEFORE rxMessageSubscription.first")
        let rxEventFromSubscription = try #require(await rxMessageSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxMessageSubscription.first")
        #expect(areMessagesEqualModuloNonSerialVersionInfo(rxEventFromSubscription.message, txMessageAfterRxSubscribe))

        // MARK: - Message Reactions (Summary)

        let messageToReact = txMessageBeforeRxSubscribe

        let rxMessageReactionsSubscription = rxRoom.messages.reactions.subscribe()

        Self.logAwait("BEFORE txRoom.messages.reactions.send (👍)")
        try await txRoom.messages.reactions.send(forMessageWithSerial: messageToReact.serial, params: .init(name: "👍"))
        Self.logAwait("AFTER txRoom.messages.reactions.send (👍)")
        Self.logAwait("BEFORE txRoom.messages.reactions.send (🎉)")
        try await txRoom.messages.reactions.send(forMessageWithSerial: messageToReact.serial, params: .init(name: "🎉"))
        Self.logAwait("AFTER txRoom.messages.reactions.send (🎉)")

        // Before deleting, fetch the reactions summary for txClientID and check its contents
        Self.logAwait("BEFORE rxRoom.messages.reactions.clientReactions")
        let reactionsForClient = try await rxRoom.messages.reactions.clientReactions(
            forMessageWithSerial: messageToReact.serial,
            clientID: txClientID,
        )
        Self.logAwait("AFTER rxRoom.messages.reactions.clientReactions")
        #expect(reactionsForClient.distinct["👍"]?.clipped == true)
        #expect(reactionsForClient.distinct["👍"]?.clientIDs == [txClientID])

        Self.logAwait("BEFORE txRoom.messages.reactions.delete (👍)")
        try await txRoom.messages.reactions.delete(fromMessageWithSerial: messageToReact.serial, params: .init(name: "👍"))
        Self.logAwait("AFTER txRoom.messages.reactions.delete (👍)")
        Self.logAwait("BEFORE txRoom.messages.reactions.delete (🎉)")
        try await txRoom.messages.reactions.delete(fromMessageWithSerial: messageToReact.serial, params: .init(name: "🎉"))
        Self.logAwait("AFTER txRoom.messages.reactions.delete (🎉)")

        var reactionSummaryEvents = [MessageReactionSummaryEvent]()

        for await event in rxMessageReactionsSubscription {
            reactionSummaryEvents.append(event)
            if reactionSummaryEvents.count == 4 {
                break
            }
        }

        #expect(reactionSummaryEvents[0].messageSerial == messageToReact.serial)
        #expect(reactionSummaryEvents[0].reactions.unique.isEmpty)
        #expect(reactionSummaryEvents[0].reactions.multiple.isEmpty)
        #expect(reactionSummaryEvents[0].reactions.distinct.count == 1)
        _ = reactionSummaryEvents[0].reactions.distinct.map { key, value in
            #expect(key == "👍")
            #expect(value.total == 1)
            #expect(value.clientIDs == [messageToReact.clientID])
        }

        #expect(reactionSummaryEvents[1].messageSerial == messageToReact.serial)
        #expect(reactionSummaryEvents[1].reactions.unique.isEmpty)
        #expect(reactionSummaryEvents[1].reactions.multiple.isEmpty)
        #expect(reactionSummaryEvents[1].reactions.distinct.count == 2)

        #expect(reactionSummaryEvents[2].messageSerial == messageToReact.serial)
        #expect(reactionSummaryEvents[2].reactions.unique.isEmpty)
        #expect(reactionSummaryEvents[2].reactions.multiple.isEmpty)
        #expect(reactionSummaryEvents[2].reactions.distinct.count == 1)
        _ = reactionSummaryEvents[2].reactions.distinct.map { key, value in
            #expect(key == "🎉")
            #expect(value.total == 1)
            #expect(value.clientIDs == [messageToReact.clientID])
        }

        #expect(reactionSummaryEvents[3].messageSerial == messageToReact.serial)
        #expect(reactionSummaryEvents[3].reactions.unique.isEmpty)
        #expect(reactionSummaryEvents[3].reactions.multiple.isEmpty)
        #expect(reactionSummaryEvents[3].reactions.distinct.isEmpty)

        // MARK: - Message Reactions (Raw)

        let rxMessageRawReactionsSubscription = rxRoom.messages.reactions.subscribeRaw()

        Self.logAwait("BEFORE txRoom.messages.reactions.send (🔥)")
        try await txRoom.messages.reactions.send(forMessageWithSerial: messageToReact.serial, params: .init(name: "🔥"))
        Self.logAwait("AFTER txRoom.messages.reactions.send (🔥)")
        Self.logAwait("BEFORE txRoom.messages.reactions.send (😆)")
        try await txRoom.messages.reactions.send(forMessageWithSerial: messageToReact.serial, params: .init(name: "😆"))
        Self.logAwait("AFTER txRoom.messages.reactions.send (😆)")
        Self.logAwait("BEFORE txRoom.messages.reactions.delete (😆)")
        try await txRoom.messages.reactions.delete(fromMessageWithSerial: messageToReact.serial, params: .init(name: "😆")) // not deleting 🔥 to check it later in history request
        Self.logAwait("AFTER txRoom.messages.reactions.delete (😆)")

        var reactionRawEvents = [MessageReactionRawEvent]()

        for await event in rxMessageRawReactionsSubscription {
            reactionRawEvents.append(event)
            if reactionRawEvents.count == 3 {
                break
            }
        }

        #expect(reactionRawEvents[0].type == .create)
        #expect(reactionRawEvents[0].reaction.name == "🔥")
        #expect(reactionRawEvents[0].reaction.messageSerial == messageToReact.serial)

        #expect(reactionRawEvents[1].type == .create)
        #expect(reactionRawEvents[1].reaction.name == "😆")
        #expect(reactionRawEvents[1].reaction.messageSerial == messageToReact.serial)

        #expect(reactionRawEvents[2].type == .delete)
        #expect(reactionRawEvents[2].reaction.name == "😆")
        #expect(reactionRawEvents[2].reaction.messageSerial == messageToReact.serial)

        // Wait a little before requesting history
        Self.logAwait("BEFORE Task.sleep (2s)")
        try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
        Self.logAwait("AFTER Task.sleep (2s)")

        // (7) Fetch historical messages from before subscribing, and check we get txMessageBeforeRxSubscribe

        /*
         TODO: This line should just be

         let messages = try await rxMessageSubscription.historyBeforeSubscribe(withParams: .init())

         but sometimes `messages.items` is coming back empty. Andy said in
         https://ably-real-time.slack.com/archives/C03JDBVM5MY/p1733220395208909
         that

         > new materialised history system doesn't currently support "live"
         > history (realtime implementation detail) - so we're approximating the
         > behaviour

         and indicated that the right workaround for now is to introduce a
         wait. So we retry the fetching of history until we get a non-empty
         result.

         Revert this (https://github.com/ably/ably-chat-swift/issues/175) once it's fixed in Realtime.
         */
        Self.logAwait("BEFORE rxMessagesHistory fetch loop")
        let rxMessagesHistory = try await {
            while true {
                Self.logAwait("BEFORE rxMessageSubscription.historyBeforeSubscribe")
                let messages = try await rxMessageSubscription.historyBeforeSubscribe(withParams: .init())
                Self.logAwait("AFTER rxMessageSubscription.historyBeforeSubscribe")
                if !messages.items.isEmpty {
                    return messages
                }
                // Wait 1 second before retrying the history fetch
                Self.logAwait("BEFORE Task.sleep (1s retry)")
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                Self.logAwait("AFTER Task.sleep (1s retry)")
            }
        }()
        Self.logAwait("AFTER rxMessagesHistory fetch loop")
        try #require(rxMessagesHistory.items.count == 1)

        let rxMessageFromHistory = rxMessagesHistory.items[0]
        #expect(rxMessageFromHistory.serial == txMessageBeforeRxSubscribe.serial) // rxMessageFromHistory contains reactions and txMessageBeforeRxSubscribe doesn't, so we only compare serials

        let rxMessageFromHistoryReactions = rxMessageFromHistory.reactions
        #expect(rxMessageFromHistoryReactions.unique.isEmpty)
        #expect(rxMessageFromHistoryReactions.multiple.isEmpty)
        #expect(rxMessageFromHistoryReactions.distinct.count == 1)
        _ = rxMessageFromHistoryReactions.distinct.map { key, value in
            #expect(key == "🔥")
            #expect(value.total == 1)
            #expect(value.clientIDs == [messageToReact.clientID])
        }

        // (8) Get a single message by its serial
        Self.logAwait("BEFORE rxRoom.messages.get")
        let retrievedMessage = try await rxRoom.messages.get(withSerial: rxMessageFromHistory.serial)
        Self.logAwait("AFTER rxRoom.messages.get")
        #expect(retrievedMessage.serial == rxMessageFromHistory.serial)
        #expect(retrievedMessage.text == rxMessageFromHistory.text)
        #expect(retrievedMessage.clientID == rxMessageFromHistory.clientID)
        // Verify the retrieved message has the same reaction summary
        #expect(retrievedMessage.reactions.distinct.count == rxMessageFromHistory.reactions.distinct.count)

        // MARK: - Editing and Deleting Messages

        // Reuse message subscription and message from (5) and (6) above
        let rxMessageEditDeleteSubscription = rxMessageSubscription
        let messageToEditDelete = txMessageAfterRxSubscribe

        // (1) Edit the message on the other client
        Self.logAwait("BEFORE txRoom.messages.update")
        let txEditedMessage = try await txRoom.messages.update(
            withSerial: messageToEditDelete.serial,
            params: .init(
                text: "edited message",
                metadata: ["someEditedKey": 123, "someOtherEditedKey": "foo"],
                headers: nil,
            ),
            details: .init(description: "random", metadata: nil),
        )
        Self.logAwait("AFTER txRoom.messages.update")

        // (2) Check that we received the edited message on the subscription
        Self.logAwait("BEFORE rxMessageEditDeleteSubscription.first (edited)")
        let rxEditedEventFromSubscription = try #require(await rxMessageEditDeleteSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxMessageEditDeleteSubscription.first (edited)")
        let rxEditedMessageFromSubscription = rxEditedEventFromSubscription.message
        // The createdAt varies by milliseconds so we can't compare the entire objects directly
        #expect(rxEditedMessageFromSubscription.serial == txEditedMessage.serial)
        #expect(rxEditedMessageFromSubscription.clientID == txEditedMessage.clientID)
        #expect(rxEditedMessageFromSubscription.version.serial == txEditedMessage.version.serial)
        #expect(rxEditedMessageFromSubscription.serial == txEditedMessage.serial)
        // Ensures text has been edited from original message
        #expect(rxEditedMessageFromSubscription.text == txEditedMessage.text)
        // Ensure headers are now null when compared to original message
        #expect(rxEditedMessageFromSubscription.headers == txEditedMessage.headers)
        // Ensures metadata has been updated from original message
        #expect(rxEditedMessageFromSubscription.metadata == txEditedMessage.metadata)

        // (3) Delete the message on the other client
        Self.logAwait("BEFORE txRoom.messages.delete")
        let txDeleteMessage = try await txRoom.messages.delete(
            withSerial: rxEditedMessageFromSubscription.serial,
            details: .init(
                description: "deleted in testing",
                metadata: ["foo": "bar"],
            ),
        )
        Self.logAwait("AFTER txRoom.messages.delete")

        // (4) Check that we received the deleted message on the subscription
        Self.logAwait("BEFORE rxMessageEditDeleteSubscription.first (deleted)")
        let rxDeletedEventFromSubscription = try #require(await rxMessageEditDeleteSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxMessageEditDeleteSubscription.first (deleted)")
        let rxDeletedMessageFromSubscription = rxDeletedEventFromSubscription.message
        // The createdAt varies by milliseconds so we can't compare the entire objects directly
        #expect(rxDeletedMessageFromSubscription.serial == txDeleteMessage.serial)
        #expect(rxDeletedMessageFromSubscription.clientID == txDeleteMessage.clientID)
        #expect(rxDeletedMessageFromSubscription.version.serial == txDeleteMessage.version.serial)
        #expect(rxDeletedMessageFromSubscription.serial == txDeleteMessage.serial)
        #expect(rxDeletedMessageFromSubscription.text.isEmpty)
        #expect(rxDeletedMessageFromSubscription.headers.isEmpty)
        #expect(rxDeletedMessageFromSubscription.metadata.isEmpty)
        #expect(rxDeletedMessageFromSubscription.version.metadata == ["foo": "bar"])

        // MARK: - Room Reactions

        // (1) Subscribe to reactions
        let rxReactionSubscription = rxRoom.reactions.subscribe()

        // (2) Now that we're subscribed to reactions, send a reaction on the other client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.reactions.send")
        try await txRoom.reactions.send(
            withParams: .init(
                name: "heart",
                metadata: ["someMetadataKey": 123, "someOtherMetadataKey": "foo"],
                headers: ["someHeadersKey": 456, "someOtherHeadersKey": "bar"],
            ),
        )
        Self.logAwait("AFTER txRoom.reactions.send")
        Self.logAwait("BEFORE rxReactionSubscription.first")
        let rxReactionFromSubscription = try #require(await rxReactionSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxReactionSubscription.first")
        #expect(rxReactionFromSubscription.reaction.name == "heart")
        #expect(rxReactionFromSubscription.reaction.metadata == ["someMetadataKey": .number(123), "someOtherMetadataKey": .string("foo")])
        #expect(rxReactionFromSubscription.reaction.headers == ["someHeadersKey": .number(456), "someOtherHeadersKey": .string("bar")])

        // MARK: - Occupancy

        // It can take a moment for the occupancy to update from the clients connecting above, so we'll wait a 2 seconds here.
        Self.logAwait("BEFORE Task.sleep (2s for occupancy)")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        Self.logAwait("AFTER Task.sleep (2s for occupancy)")

        // (1) Get current occupancy
        Self.logAwait("BEFORE rxRoom.occupancy.get() (initial)")
        let currentOccupancy = try await rxRoom.occupancy.get()
        Self.logAwait("AFTER rxRoom.occupancy.get() (initial)")
        #expect(currentOccupancy.connections != 0) // this flucuates dependant on the number of clients connected e.g. simulators running the test, hence why checking for non-zero
        #expect(currentOccupancy.presenceMembers == 0) // not yet entered presence

        // (2) Subscribe to occupancy
        let rxOccupancySubscription = rxRoom.occupancy.subscribe()

        // (3) Attach the room so we can perform presence operations
        Self.logAwait("BEFORE txRoom.attach()")
        try await txRoom.attach()
        Self.logAwait("AFTER txRoom.attach()")

        // (4) Enter presence on the other client and check that we receive the updated occupancy on the subscription
        Self.logAwait("BEFORE txRoom.presence.enter()")
        try await txRoom.presence.enter()
        Self.logAwait("AFTER txRoom.presence.enter()")

        // (5) Check that we received an updated presence count on the subscription
        Self.logAwait("BEFORE rxOccupancySubscription.first (presenceMembers == 1)")
        _ = try #require(await rxOccupancySubscription.first { @Sendable occupancyEvent in
            occupancyEvent.occupancy.presenceMembers == 1 // 1 for txClient entering presence
        })
        Self.logAwait("AFTER rxOccupancySubscription.first (presenceMembers == 1)")

        // (6) Check that we received an updated presence count when getting the occupancy
        Self.logAwait("BEFORE rxRoom.occupancy.get() (after enter)")
        let rxOccupancyAfterTxEnter = try await rxRoom.occupancy.get()
        Self.logAwait("AFTER rxRoom.occupancy.get() (after enter)")
        #expect(rxOccupancyAfterTxEnter.presenceMembers == 1) // 1 for txClient entering presence

        // (7) Leave presence on the other client and check that we receive the updated occupancy on the subscription
        Self.logAwait("BEFORE txRoom.presence.leave()")
        try await txRoom.presence.leave()
        Self.logAwait("AFTER txRoom.presence.leave()")

        // (8) Check that we received an updated presence count on the subscription
        Self.logAwait("BEFORE rxOccupancySubscription.first (presenceMembers == 0)")
        _ = try #require(await rxOccupancySubscription.first { @Sendable occupancyEvent in
            occupancyEvent.occupancy.presenceMembers == 0 // 0 for txClient leaving presence
        })
        Self.logAwait("AFTER rxOccupancySubscription.first (presenceMembers == 0)")

        // (9) Check that we received an updated presence count when getting the occupancy
        Self.logAwait("BEFORE rxRoom.occupancy.get() (after leave)")
        let rxOccupancyAfterTxLeave = try await rxRoom.occupancy.get()
        Self.logAwait("AFTER rxRoom.occupancy.get() (after leave)")
        #expect(rxOccupancyAfterTxLeave.presenceMembers == 0) // 0 for txClient leaving presence

        // MARK: - Presence

        // (1) Subscribe to all presence events
        let rxPresenceSubscription = rxRoom.presence.subscribe()

        // (2) Send `.enter` presence event with custom data on the other client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.enter (tx)")
        try await txRoom.presence.enter(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.enter (tx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (enter tx)")
        let rxPresenceEnterTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (enter tx)")
        #expect(rxPresenceEnterTxEvent.type == .enter)
        #expect(rxPresenceEnterTxEvent.member.data == ["randomData": "randomValue"])

        // (3) Fetch rxClient's presence members and check that txClient is there
        Self.logAwait("BEFORE rxRoom.presence.get()")
        let rxPresenceMembers = try await rxRoom.presence.get()
        Self.logAwait("AFTER rxRoom.presence.get()")
        #expect(rxPresenceMembers.count == 1)
        #expect(rxPresenceMembers[0].data == ["randomData": "randomValue"])

        // (4) Send `.update` presence event with custom data on the other client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.update (tx)")
        try await txRoom.presence.update(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.update (tx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (update tx)")
        let rxPresenceUpdateTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (update tx)")
        #expect(rxPresenceUpdateTxEvent.type == .update)
        #expect(rxPresenceUpdateTxEvent.member.data == ["randomData": "randomValue"])

        // (5) Send `.leave` presence event with custom data on the other client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.leave (tx)")
        try await txRoom.presence.leave(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.leave (tx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (leave tx)")
        let rxPresenceLeaveTxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (leave tx)")
        #expect(rxPresenceLeaveTxEvent.type == .leave)
        #expect(rxPresenceLeaveTxEvent.member.data == ["randomData": "randomValue"])

        // (6) Send `.enter` presence event with custom data on our client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.enter (rx)")
        try await txRoom.presence.enter(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.enter (rx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (enter rx)")
        let rxPresenceEnterRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (enter rx)")
        #expect(rxPresenceEnterRxEvent.type == .enter)
        #expect(rxPresenceEnterRxEvent.member.data == ["randomData": "randomValue"])

        // (7) Send `.update` presence event with custom data on our client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.update (rx)")
        try await txRoom.presence.update(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.update (rx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (update rx)")
        let rxPresenceUpdateRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (update rx)")
        #expect(rxPresenceUpdateRxEvent.type == .update)
        #expect(rxPresenceUpdateRxEvent.member.data == ["randomData": "randomValue"])

        // (8) Send `.leave` presence event with custom data on our client and check that we receive it on the subscription
        Self.logAwait("BEFORE txRoom.presence.leave (rx)")
        try await txRoom.presence.leave(withData: ["randomData": "randomValue"])
        Self.logAwait("AFTER txRoom.presence.leave (rx)")
        Self.logAwait("BEFORE rxPresenceSubscription.first (leave rx)")
        let rxPresenceLeaveRxEvent = try #require(await rxPresenceSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxPresenceSubscription.first (leave rx)")
        #expect(rxPresenceLeaveRxEvent.type == .leave)
        #expect(rxPresenceLeaveRxEvent.member.data == ["randomData": "randomValue"])

        // MARK: - Typing Indicators

        // (1) Subscribe to typing indicators
        let rxTypingSubscription = rxRoom.typing.subscribe()

        // (2) Start typing on txRoom and check that we receive the typing event on the subscription
        Self.logAwait("BEFORE txRoom.typing.keystroke()")
        try await txRoom.typing.keystroke()
        Self.logAwait("AFTER txRoom.typing.keystroke()")

        // (3) Wait for the typing event to be received
        var typingEvents: [TypingSetEvent] = []
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

        // MARK: - Typing Indicators Heartbeat Throttle

        // This should be tested using the RxRoom since it is the client themselves that are typing

        // (1) Start repeatedly typing on rxRoom
        for i in 0 ..< 5 {
            Self.logAwait("BEFORE rxRoom.typing.keystroke() \(i)")
            try await rxRoom.typing.keystroke()
            Self.logAwait("AFTER rxRoom.typing.keystroke() \(i)")
        }

        // (2) Wait enough time for the events to come through
        let throttle: TimeInterval = 1
        let startTime = Date()
        typingEvents = []
        for await typingEvent in rxTypingSubscription {
            typingEvents.append(typingEvent)

            if Date().timeIntervalSince(startTime) >= throttle {
                break
            }
        }

        // (3) Check that we received only 1 typing event
        #expect(typingEvents.count { event in
            event.change.type == .started
        } == 1)

        // (3) Check that we received 1 stopped typing event
        #expect(typingEvents.count { event in
            event.change.type == .stopped
        } == 1)

        // (5) Check that we received a total of 2 typing events, and there are no currently typing users
        #expect(typingEvents.count == 2)
        #expect(typingEvents[1].currentlyTyping.isEmpty)

        // MARK: - Detach

        // (1) Detach the room
        Self.logAwait("BEFORE rxRoom.detach()")
        try await rxRoom.detach()
        Self.logAwait("AFTER rxRoom.detach()")

        // (2) Check that we received a DETACHED status change as a result of detaching the room
        Self.logAwait("BEFORE rxRoomStatusSubscription.first (DETACHED)")
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .detached
        })
        Self.logAwait("AFTER rxRoomStatusSubscription.first (DETACHED)")
        #expect(rxRoom.status == .detached)

        // MARK: - Release

        // (1) Release the room
        Self.logAwait("BEFORE rxClient.rooms.release")
        await rxClient.rooms.release(named: roomName)
        Self.logAwait("AFTER rxClient.rooms.release")

        // (2) Check that we received a RELEASED status change as a result of releasing the room
        Self.logAwait("BEFORE rxRoomStatusSubscription.first (RELEASED)")
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .released
        })
        Self.logAwait("AFTER rxRoomStatusSubscription.first (RELEASED)")
        #expect(rxRoom.status == .released)

        // (3) Fetch the room we just released and check it's a new object
        Self.logAwait("BEFORE rxClient.rooms.get (post-release)")
        let postReleaseRxRoom = try await rxClient.rooms.get(named: roomName, options: .init())
        Self.logAwait("AFTER rxClient.rooms.get (post-release)")
        #expect(postReleaseRxRoom !== rxRoom)
    }

    /// This test ensures that ably-cocoa isn't making double percent-encoding
    @Test
    func roomNameWithSlashInTheName() async throws {
        // MARK: - Setup + Attach

        Self.logAwait("BEFORE Sandbox.createAPIKey()")
        let apiKey = try await Sandbox.createAPIKey()
        Self.logAwait("AFTER Sandbox.createAPIKey()")

        // (1) Create a couple of chat clients — one for sending and one for receiving
        let txClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "tx-slash")
        let rxClient = Self.createSandboxChatClient(apiKey: apiKey, loggingLabel: "rx-slash")

        // (2) Fetch a room with a slash in the name
        let roomName = "room/with/slash"
        Self.logAwait("BEFORE txClient.rooms.get()")
        let txRoom = try await txClient.rooms.get(
            named: roomName,
            options: .init(),
        )
        Self.logAwait("AFTER txClient.rooms.get()")
        Self.logAwait("BEFORE rxClient.rooms.get()")
        let rxRoom = try await rxClient.rooms.get(
            named: roomName,
            options: .init(),
        )
        Self.logAwait("AFTER rxClient.rooms.get()")

        // (3) Subscribe to room status
        let rxRoomStatusSubscription = rxRoom.onStatusChange()

        // (4) Attach the room so we can receive messages on it
        Self.logAwait("BEFORE rxRoom.attach()")
        try await rxRoom.attach()
        Self.logAwait("AFTER rxRoom.attach()")

        // (5) Check that the room is attached
        #expect(rxRoom.status == .attached)

        // MARK: - Send and receive messages

        // (1) Subscribe to messages
        let rxMessageSubscription = rxRoom.messages.subscribe()

        // (2) Send a message on the tx client and check that we receive it on the rx subscription
        Self.logAwait("BEFORE txRoom.messages.send")
        let txMessage = try await txRoom.messages.send(
            withParams: .init(
                text: "Hello from room with slash in the name",
            ),
        )
        Self.logAwait("AFTER txRoom.messages.send")

        // (3) Wait for the message to be received on the subscription
        Self.logAwait("BEFORE rxMessageSubscription.first")
        let rxEventFromSubscription = try #require(await rxMessageSubscription.first { @Sendable _ in true })
        Self.logAwait("AFTER rxMessageSubscription.first")

        // (4) Verify the received message matches the sent message
        #expect(rxEventFromSubscription.message.text == txMessage.text)

        // MARK: - Cleanup

        // (1) Detach the room
        Self.logAwait("BEFORE rxRoom.detach()")
        try await rxRoom.detach()
        Self.logAwait("AFTER rxRoom.detach()")

        // (2) Check that we received a DETACHED status change
        Self.logAwait("BEFORE rxRoomStatusSubscription.first (DETACHED)")
        _ = try #require(await rxRoomStatusSubscription.first { @Sendable statusChange in
            statusChange.current == .detached
        })
        Self.logAwait("AFTER rxRoomStatusSubscription.first (DETACHED)")
        #expect(rxRoom.status == .detached)

        // (3) Release the room
        Self.logAwait("BEFORE rxClient.rooms.release")
        await rxClient.rooms.release(named: roomName)
        Self.logAwait("AFTER rxClient.rooms.release")

        // (4) Check that the room was released
        #expect(rxRoom.status == .released)
    }
}

/// Compares two messages for equality, ignoring all properties of the messages' `version` except for `serial`.
private func areMessagesEqualModuloNonSerialVersionInfo(_ message1: Message, _ message2: Message) -> Bool {
    var message2Copy = message2
    message2Copy.version = message1.version
    message2Copy.version.serial = message2.version.serial

    return message1 == message2Copy
}
