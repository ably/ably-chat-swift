import Ably
@testable import AblyChat
import Testing

struct DefaultConnectionTests {
    // @spec CHA-CS2a
    // @spec CHA-CS2b
    // @spec CHA-CS3
    @Test
    func chatClientMustExposeItsCurrentStatus() async throws {
        // Given: An instance of DefaultChatClient
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init())
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)

        // When: the connection status object is constructed
        let status = await client.connection.status
        let error = await client.connection.error

        // Then: connection status and error exposed and initial status and error of the connection must be whatever status the realtime client returns whilst the connection status object is constructed
        // Should be `initialized` but `DefaultConnection` fires `ConnectionStatusManager` actor events using `Task`, so those events are asynchronous to syncronous connection's constructor. Thus:
        // TODO: revisit together with `DefaultConnection` and https://github.com/ably-labs/ably-chat-swift/issues/49
        #expect(status == .disconnected)
        #expect(error == nil)
    }

    // @spec CHA-CS4a
    // @spec CHA-CS4b
    // @spec CHA-CS4c
    // @spec CHA-CS4d
    @Test
    func chatClientMustAllowItsConnectionStatusToBeObserved() async throws {
        // Given: An instance of DefaultChatClient and a connection error
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init())
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let connectionError = ARTErrorInfo.createUnknownError()

        // When
        // (CHA-CS4d) Clients must be able to register a listener for connection status events and receive such events.
        let subscription = client.connection.onStatusChange()

        subscription.emit(.init(current: .disconnected, previous: .connecting, error: connectionError, retryIn: 1)) // arbitrary values

        let statusChange = try #require(await subscription.first { _ in true })

        // Then
        // (CHA-CS4a) Connection status update events must contain the newly entered connection status.
        // (CHA-CS4b) Connection status update events must contain the previous connection status.
        // (CHA-CS4c) Connection status update events must contain the connection error (if any) that pertains to the newly entered connection status.
        #expect(statusChange.current == .disconnected)
        #expect(statusChange.previous == .connecting)
        #expect(statusChange.error == connectionError)
    }

    // @specUntested CHA-CS4e - Currently untestable due to subscription is removed once the object is removed from memory.
    // @specUntested CHA-CS4f - Currently untestable due to subscription is removed once the object is removed from memory.

    // @spec CHA-CS5a1
    // @spec CHA-CS5a4
    @Test
    func whenConnectionGoesFromConnectedToDisconnectedTransientDisconnectTimerStarts() async throws {
        // Given:
        // An instance of DefaultChatClient, connected realtime connection and default chat connection
        let realtimeConnection = MockConnection(state: .connected)
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init(connection: realtimeConnection))
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let defaultConnection = try #require(client.connection as? DefaultConnection)

        // Transient timer subscription
        let transientTimerSubscription = await defaultConnection.testsOnly_subscribeToTransientDisconnectTimerEvents()

        // Status subscription
        let statusSubscription = defaultConnection.onStatusChange()

        // When:

        // Realtime connection status transitions from CONNECTED to DISCONNECTED
        let connectionError = ARTErrorInfo.create(withCode: 0, message: "Connection error")
        realtimeConnection.transitionToState(.disconnected, event: .disconnected, error: connectionError)

        // Then:

        // A 5 second transient disconnect timer shall be started
        let timerStartedAt = Date().timeIntervalSince1970
        let transientTimerEvent = try #require(await transientTimerSubscription.first { _ in true })
        #expect(transientTimerEvent.active)

        // (emitting artificial status change event for subscription awaiting below to return)
        let fakeError = ARTErrorInfo.create(withCode: 0, message: "Fake error")
        statusSubscription.emit(.init(current: .initialized, previous: .initialized, error: fakeError, retryIn: 1)) // arbitrary values

        // Then:
        let statusChange1 = try #require(await statusSubscription.first { _ in true })
        let statusChange2 = try #require(await statusSubscription.first { _ in true })

        // Transient disconnect timer interval is 5 seconds
        #expect(Date().timeIntervalSince1970 - timerStartedAt >= 5)

        // Chat client connection status must not change - first emitted status was artificial and was not generated by `transitionToState:`
        #expect(statusChange1.error == fakeError)

        // And the second status chage was generated by `transitionToState:` when transient timer has expired (CHA-CS5a4)
        #expect(statusChange2.error == connectionError)
    }

    // @spec CHA-CS5a2
    @Test
    func whenConnectionGoesFromDisconnectedToConnectingNoStatusChangeIsEmitted() async throws {
        // Given:
        // An instance of DefaultChatClient, connected realtime connection and default chat connection
        let realtimeConnection = MockConnection(state: .connected)
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init(connection: realtimeConnection))
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let defaultConnection = try #require(client.connection as? DefaultConnection)

        // Transient timer subscription
        let transientTimerSubscription = await defaultConnection.testsOnly_subscribeToTransientDisconnectTimerEvents()

        // Status subscription
        let statusSubscription = defaultConnection.onStatusChange()

        // When:

        // Transient disconnect timer is active
        realtimeConnection.transitionToState(.disconnected, event: .disconnected) // starting timer by going to DISCONNECTED
        let transientTimerEvent = try #require(await transientTimerSubscription.first { _ in true })
        #expect(transientTimerEvent.active)

        // And the realtime connection status changes to CONNECTING
        realtimeConnection.transitionToState(.connecting, event: .connecting)

        // Or to DISCONNECTED
        realtimeConnection.transitionToState(.disconnected, event: .disconnected)

        // (emitting artificial status change event for subscription awaiting below to return)
        let fakeError = ARTErrorInfo.create(withCode: 0, message: "Fake error")
        statusSubscription.emit(.init(current: .initialized, previous: .initialized, error: fakeError, retryIn: 1)) // arbitrary values

        // Then:
        let statusChange1 = try #require(await statusSubscription.first { _ in true })
        let statusChange2 = try #require(await statusSubscription.first { _ in true })

        // Chat client connection status must not change - first emitted status was artificial and was not generated by the calls to `transitionToState:`
        #expect(statusChange1.error == fakeError)

        // And the second status change was generated by `transitionToState:` when transient timer has expired
        #expect(statusChange2.error == nil)
    }

    // @spec CHA-CS5a3
    @Test
    func whenConnectionGoesToConnectedStatusChangeShouldBeEmitted() async throws {
        // Given:
        // An instance of DefaultChatClient, connected realtime connection and default chat connection
        let realtimeConnection = MockConnection(state: .connected)
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init(connection: realtimeConnection))
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let defaultConnection = try #require(client.connection as? DefaultConnection)

        // Transient timer subscription
        let transientTimerSubscription = await defaultConnection.testsOnly_subscribeToTransientDisconnectTimerEvents()

        // Status subscription
        let statusSubscription = defaultConnection.onStatusChange()

        // When:

        // Transient disconnect timer is active
        let timerStartedAt = Date().timeIntervalSince1970
        realtimeConnection.transitionToState(.disconnected, event: .disconnected) // starting timer by going to DISCONNECTED
        let transientTimerEvent = try #require(await transientTimerSubscription.first { _ in true })
        #expect(transientTimerEvent.active)

        // And the realtime connection status changes to CONNECTED
        realtimeConnection.transitionToState(.connected, event: .connected)

        let statusChange = try #require(await statusSubscription.first { _ in true })

        // Then:

        // The library shall cancel the transient disconnect timer (less than 5 seconds -> was cancelled)
        #expect(Date().timeIntervalSince1970 - timerStartedAt < 1)

        // The superseding status change shall be emitted
        #expect(statusChange.current == .connected)
        #expect(statusChange.error == nil)
    }

    // @spec CHA-CS5a3
    @Test
    func whenConnectionGoesToSuspendedStatusChangeShouldBeEmitted() async throws {
        // Given:
        // An instance of DefaultChatClient, connected realtime connection and default chat connection
        let realtimeConnection = MockConnection(state: .connected)
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init(connection: realtimeConnection))
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let defaultConnection = try #require(client.connection as? DefaultConnection)

        // Transient timer subscription
        let transientTimerSubscription = await defaultConnection.testsOnly_subscribeToTransientDisconnectTimerEvents()

        // Status subscription
        let statusSubscription = defaultConnection.onStatusChange()

        // When:

        // Transient disconnect timer is active
        let timerStartedAt = Date().timeIntervalSince1970
        realtimeConnection.transitionToState(.disconnected, event: .disconnected) // starting timer by going to DISCONNECTED
        let transientTimerEvent = try #require(await transientTimerSubscription.first { _ in true })
        #expect(transientTimerEvent.active)

        // And the realtime connection status changes to SUSPENDED
        realtimeConnection.transitionToState(.suspended, event: .suspended)

        let statusChange = try #require(await statusSubscription.first { _ in true })

        // Then:

        // The library shall cancel the transient disconnect timer (less than 5 seconds -> was cancelled)
        #expect(Date().timeIntervalSince1970 - timerStartedAt < 1)

        // The superseding status change shall be emitted
        #expect(statusChange.current == .suspended)
    }

    // @spec CHA-CS5a3
    @Test
    func whenConnectionGoesToFailedStatusChangeShouldBeEmitted() async throws {
        // Given:
        // An instance of DefaultChatClient, connected realtime connection and default chat connection
        let realtimeConnection = MockConnection(state: .connected)
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init(connection: realtimeConnection))
        let client = DefaultChatClient(realtime: realtime, clientOptions: nil)
        let defaultConnection = try #require(client.connection as? DefaultConnection)

        // Transient timer subscription
        let transientTimerSubscription = await defaultConnection.testsOnly_subscribeToTransientDisconnectTimerEvents()

        // Status subscription
        let statusSubscription = defaultConnection.onStatusChange()

        // When:

        // Transient disconnect timer is active
        let timerStartedAt = Date().timeIntervalSince1970
        realtimeConnection.transitionToState(.disconnected, event: .disconnected) // starting timer by going to DISCONNECTED
        let transientTimerEvent = try #require(await transientTimerSubscription.first { _ in true })
        #expect(transientTimerEvent.active)

        // And the realtime connection status changes to FAILED
        realtimeConnection.transitionToState(.failed, event: .failed, error: ARTErrorInfo.create(withCode: 0, message: "Connection error"))

        let statusChange = try #require(await statusSubscription.first { _ in true })

        // Then:

        // The library shall cancel the transient disconnect timer (less than 5 seconds -> was cancelled)
        #expect(Date().timeIntervalSince1970 - timerStartedAt < 1)

        // The superseding status change shall be emitted
        #expect(statusChange.current == .failed)
        #expect(statusChange.error != nil)
    }

    // @specUntested CHA-CS5b - The implementation of this part is not clear. I've commented extra call for emitting event because I think it's in the wrong place, see `subscription.emit(statusChange)` call with "this call shouldn't be here" comment in "DefaultConnection.swift".
}
