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
        let txRoom = try await txClient.rooms.get(roomID: roomID, options: .init(reactions: .init()))
        let rxRoom = try await rxClient.rooms.get(roomID: roomID, options: .init(reactions: .init()))

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

        // MARK: - Detach

        // (12) Detach the room
        try await rxRoom.detach()

        // (13) Check that we received a DETACHED status change as a result of detaching the room
        _ = try #require(await rxRoomStatusSubscription.first { $0.current == .detached })
        #expect(await rxRoom.status == .detached)

        // MARK: - Release

        // (14) Release the room
        try await rxClient.rooms.release(roomID: roomID)

        // (15) Check that we received a RELEASED status change as a result of releasing the room
        _ = try #require(await rxRoomStatusSubscription.first { $0.current == .released })
        #expect(await rxRoom.status == .released)

        // (16) Fetch the room we just released and check it’s a new object
        let postReleaseRxRoom = try await rxClient.rooms.get(roomID: roomID, options: .init())
        #expect(postReleaseRxRoom !== rxRoom)
    }
}
