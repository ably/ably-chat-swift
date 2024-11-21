import Ably
import AblyChat
import Testing

/// Some very basic integration tests, just to check that things are kind of working.
///
/// It would be nice to give this a time limit, but unfortunately the `timeLimit` trait is only available on iOS 16 etc and above. CodeRabbit suggested writing a timeout function myself and wrapping the contents of the test in it, but I didn’t have time to try understanding its suggested code, so it can wait.
@Suite
struct IntegrationTests {
    private static func createSandboxRealtime(apiKey: String) -> ARTRealtime {
        let realtimeOptions = ARTClientOptions(key: apiKey)
        realtimeOptions.environment = "sandbox"
        realtimeOptions.clientId = UUID().uuidString

        return ARTRealtime(options: realtimeOptions)
    }

    private static func createSandboxChatClient(apiKey: String) -> DefaultChatClient {
        let realtime = createSandboxRealtime(apiKey: apiKey)
        return DefaultChatClient(realtime: realtime, clientOptions: nil)
    }

    @Test
    func basicIntegrationTest() async throws {
        // MARK: - Setup + Attach

        let apiKey = try await Sandbox.createAPIKey()

        // (1) Create a couple of chat clients — one for sending and one for receiving
        let txClient = Self.createSandboxChatClient(apiKey: apiKey)
        let rxClient = Self.createSandboxChatClient(apiKey: apiKey)

        // (2) Fetch a room
        let roomID = "basketball"
        let txRoom = try await txClient.rooms.get(
            roomID: roomID,
            options: .init(
                presence: .init(),
                reactions: .init(),
                occupancy: .init()
            )
        )
        let rxRoom = try await rxClient.rooms.get(
            roomID: roomID,
            options: .init(
                presence: .init(),
                reactions: .init(),
                occupancy: .init()
            )
        )

        // (3) Subscribe to room status
        let rxRoomStatusSubscription = await rxRoom.onStatusChange(bufferingPolicy: .unbounded)

        // (4) Attach the room so we can receive messages on it
        try await rxRoom.attach()

        // (5) Check that we received an ATTACHED status change as a result of attaching the room
        _ = try #require(await rxRoomStatusSubscription.first { $0.current == .attached })
        #expect(await rxRoom.status == .attached)

        // MARK: - Send and receive messages

        // (6) Send a message before subscribing to messages, so that later on we can check history works.

        // Create a throwaway subscription and wait for it to receive a message. This is to make sure that rxRoom has seen the message that we send here, so that the first message we receive on the subscription created in (7) is that which we’ll send in (8), and not that which we send here.
        let throwawayRxMessageSubscription = try await rxRoom.messages.subscribe(bufferingPolicy: .unbounded)

        // Send the message
        let txMessageBeforeRxSubscribe = try await txRoom.messages.send(params: .init(text: "Hello from txRoom, before rxRoom subscribe"))

        // Wait for rxRoom to see the message we just sent
        let throwawayRxMessage = try #require(await throwawayRxMessageSubscription.first { _ in true })
        #expect(throwawayRxMessage == txMessageBeforeRxSubscribe)

        // (7) Subscribe to messages
        let rxMessageSubscription = try await rxRoom.messages.subscribe(bufferingPolicy: .unbounded)

        // (8) Now that we’re subscribed to messages, send a message on the other client and check that we receive it on the subscription
        let txMessageAfterRxSubscribe = try await txRoom.messages.send(params: .init(text: "Hello from txRoom, after rxRoom subscribe"))
        let rxMessageFromSubscription = try #require(await rxMessageSubscription.first { _ in true })
        #expect(rxMessageFromSubscription == txMessageAfterRxSubscribe)

        // (9) Fetch historical messages from before subscribing, and check we get txMessageBeforeRxSubscribe
        let rxMessagesBeforeSubscribing = try await rxMessageSubscription.getPreviousMessages(params: .init())
        try #require(rxMessagesBeforeSubscribing.items.count == 1)
        #expect(rxMessagesBeforeSubscribing.items[0] == txMessageBeforeRxSubscribe)

        // MARK: - Reactions

        // (10) Subscribe to reactions
        let rxReactionSubscription = await rxRoom.reactions.subscribe(bufferingPolicy: .unbounded)

        // (11) Now that we’re subscribed to reactions, send a reaction on the other client and check that we receive it on the subscription
        try await txRoom.reactions.send(params: .init(type: "heart"))
        let rxReactionFromSubscription = try #require(await rxReactionSubscription.first { _ in true })
        #expect(rxReactionFromSubscription.type == "heart")

        // MARK: - Occupancy

        // It can take a moment for the occupancy to update from the clients connecting above, so we’ll wait a 2 seconds here.
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // (12) Get current occupancy
        let currentOccupancy = try await rxRoom.occupancy.get()
        #expect(currentOccupancy.connections != 0) // this flucuates dependant on the number of clients connected e.g. simulators running the test, hence why checking for non-zero
        #expect(currentOccupancy.presenceMembers == 0) // not yet entered presence

        // (13) Subscribe to occupancy
        let rxOccupancySubscription = await rxRoom.occupancy.subscribe(bufferingPolicy: .unbounded)

        // (14) Attach the room so we can perform presence operations
        try await txRoom.attach()

        // (15) Enter presence on the other client and check that we receive the updated occupancy on the subscription
        try await txRoom.presence.enter(data: nil)

        // It can take a moment for the occupancy to update from the clients entering presence above, so we’ll wait 2 seconds here.
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // (16) Check that we received an updated presence count when getting the occupancy
        let updatedCurrentOccupancy = try await rxRoom.occupancy.get()
        #expect(updatedCurrentOccupancy.presenceMembers == 1) // 1 for txClient entering presence

        // (17) Check that we received an updated presence count on the subscription
        let rxOccupancyEventFromSubscription = try #require(await rxOccupancySubscription.first { _ in true })

        #expect(rxOccupancyEventFromSubscription.presenceMembers == 1) // 1 for txClient entering presence

        try await txRoom.presence.leave(data: nil)

        // It can take a moment for the occupancy to update from the clients leaving presence above, so we’ll wait 2 seconds here. Important for the occupancy tests below.
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // MARK: - Presence

        // (18) Subscribe to presence
        let rxPresenceSubscription = await rxRoom.presence.subscribe(events: [.enter, .leave, .update])

        // (19) Send `.enter` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.enter(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceEnterTxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceEnterTxEvent.action == .enter)
        #expect(rxPresenceEnterTxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // (20) Send `.update` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.update(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceUpdateTxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceUpdateTxEvent.action == .update)
        #expect(rxPresenceUpdateTxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // (21) Send `.leave` presence event with custom data on the other client and check that we receive it on the subscription
        try await txRoom.presence.leave(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceLeaveTxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceLeaveTxEvent.action == .leave)
        #expect(rxPresenceLeaveTxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // (22) Send `.enter` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.enter(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceEnterRxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceEnterRxEvent.action == .enter)
        #expect(rxPresenceEnterRxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // (23) Send `.update` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.update(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceUpdateRxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceUpdateRxEvent.action == .update)
        #expect(rxPresenceUpdateRxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // (24) Send `.leave` presence event with custom data on our client and check that we receive it on the subscription
        try await txRoom.presence.leave(data: .init(userCustomData: ["randomData": .string("randomValue")]))
        let rxPresenceLeaveRxEvent = try #require(await rxPresenceSubscription.first { _ in true })
        #expect(rxPresenceLeaveRxEvent.action == .leave)
        #expect(rxPresenceLeaveRxEvent.data?.userCustomData?["randomData"]?.value as? String == "randomValue")

        // MARK: - Detach

        // (25) Detach the room
        try await rxRoom.detach()

        // (26) Check that we received a DETACHED status change as a result of detaching the room
        _ = try #require(await rxRoomStatusSubscription.first { $0.current == .detached })
        #expect(await rxRoom.status == .detached)

        // MARK: - Release

        // (27) Release the room
        try await rxClient.rooms.release(roomID: roomID)

        // (28) Check that we received a RELEASED status change as a result of releasing the room
        _ = try #require(await rxRoomStatusSubscription.first { $0.current == .released })
        #expect(await rxRoom.status == .released)

        // (29) Fetch the room we just released and check it’s a new object
        let postReleaseRxRoom = try await rxClient.rooms.get(roomID: roomID, options: .init())
        #expect(postReleaseRxRoom !== rxRoom)
    }
}
