# Ably Chat SDK for Swift

<p style="text-align: left">
    <img src="https://badgen.net/github/license/3scale/saas-operator" alt="License" />
    <img src="https://img.shields.io/badge/version-0.1.0--SNAPSHOT-2ea44f" alt="version: 0.1.0-SNAPSHOT" />
</p>

Ably Chat is a set of purpose-built APIs for a host of chat features enabling you to create 1:1, 1:Many, Many:1 and Many:Many chat rooms for
any scale. It is designed to meet a wide range of chat use cases, such as livestreams, in-game communication, customer support, or social
interactions in SaaS products. Built on [Ably's](https://ably.com/) core service, it abstracts complex details to enable efficient chat
architectures.

Get started using the [📚 documentation](https://ably.com/docs/products/chat).

![Ably Chat Header](/images/ably-chat-github-header.png)

## Supported Platforms

- macOS 11 and above
- iOS 14 and above
- tvOS 14 and above

## Requirements

Xcode 16 or later.

## Installation

The SDK is distributed as a Swift package and can hence be installed using Xcode (search for `github.com/ably/ably-chat-swift` package) or by adding it as a dependency in your package’s `Package.swift`:

```swift
.package(url: "https://github.com/ably/ably-chat-swift", from: "0.1.0")
```

## Supported chat features

This project is under development so we will be incrementally adding new features. At this stage, you'll find APIs for the following chat
features:

- Chat rooms for 1:1, 1:many, many:1 and many:many participation.
- Sending and receiving chat messages.
- Online status aka presence of chat participants.
- Chat room occupancy, i.e total number of connections and presence members.
- Typing indicators
- Room-level reactions (ephemeral at this stage)

If there are other features you'd like us to prioritize, please [let us know](https://forms.gle/mBw9M53NYuCBLFpMA).

## Usage

You will need the following prerequisites:

- An Ably account

  - You can [sign up](https://ably.com/signup) to the generous free tier.

- An Ably API key
  - Use the default or create a new API key in an app within
    your [Ably account dashboard](https://ably.com/dashboard).
  - Make sure your API key has the
    following [capabilities](https://ably.com/docs/auth/capabilities): `publish`, `subscribe`, `presence`, `history` and
    `channel-metadata`.

To instantiate the Chat SDK, create an [Ably client](https://ably.com/docs/getting-started/setup) and pass it into the Chat constructor:

```swift
import Ably
import AblyChat

let realtimeOptions = ARTClientOptions()
realtimeOptions.key = "<API_KEY>"
realtimeOptions.clientId = "<clientId>"
let realtime = ARTRealtime(options: realtimeOptions)
let chatClient = DefaultChatClient(realtime: realtime, clientOptions: nil)
```

You can use [basic authentication](https://ably.com/docs/auth/basic) i.e. the API Key directly for testing purposes,
however it is strongly recommended that you use [token authentication](https://ably.com/docs/auth/token) in production
environments.

To use Chat you must also set a [`clientId`](https://ably.com/docs/auth/identified-clients) so that users are
identifiable.

## Connections

The Chat SDK uses a single connection to Ably, which is exposed via the `ChatClient#connection` property. You can use this
property to observe the connection state and take action accordingly.

### Current connection status

You can view the current connection status at any time:

```swift
let status = await chatClient.connection.status
let error = await chatClient.connection.error
```

### Subscribing to connection status changes

To subscribe to connection status changes, create a subscription with the `onStatusChange` method. You can then iterate over it using its `AsyncSequence` interface:

```swift
let subscription = chatClient.connection.onStatusChange()
for await statusChange in subscription {
    print("Connection status changed to: \(statusChange.current)")
}
```

## Chat rooms

### Creating or retrieving a chat room

You can create or retrieve a chat room with name `"basketball-stream"` this way:

```swift
let room = try await chatClient.rooms.get(roomID: "basketball-stream", options: RoomOptions())
```

The second argument to `rooms.get` is a `RoomOptions` argument, which tells the Chat SDK what features you would like your room to use and
how they should be configured.

You can also use `RoomOptions.allFeaturesEnabled` to enable all room features with the default configuration.

For example, you can set the timeout between keystrokes for typing events as part of the room options. Sensible defaults for each of the
features are provided for your convenience:

- A typing timeout (time of inactivity before typing stops) of 5 seconds.
- Entry and subscription to presence.

Here’s an example demonstrating how to specify a custom typing timeout of 3 seconds:

```swift
let room = try await chatClient.rooms.get(roomID: "basketball-stream",
                                          options: .init(typing: TypingOptions(timeout: 3.0)))
```

In order to use the same room but with different options, you must first `release` the room before requesting an instance with the changed
options (see below for more information on releasing rooms).

Note that:

- If a `release` call is currently in progress for the room (see below), then a call to `get` will wait for that to complete before completing
  itself.
- If a `get` call is currently in progress for the room and `release` is called, the `get` call will fail.

### Attaching to a room

To start receiving events on a room, it must first be attached. This can be done using the `attach` method:

```swift
try await room.attach()
```

### Detaching from a room

To stop receiving events on a room, it must be detached, which can be achieved by using the `detach` method:

```swift
room.detach()
```

Note: This does not remove any event listeners you have registered and they will begin to receive events again in the
event that the room is re-attached.

### Releasing a room

Depending on your application, you may have multiple rooms that come and go over time (e.g. if you are running 1:1 support chat). When you
are completely finished with a room, you may `release` it which allows the underlying resources to be collected:

```swift
_ = try await rooms.release(roomID: "basketball-stream")
```

Once `release` is called, the room will become unusable and you will need to get a new instance using `rooms.get`.

> [!NOTE]
> Releasing a room may be optional for many applications. If release is not called, the server will automatically tidy up
> connections and other resources associated with the room after a period of time.

### Monitoring room status

Monitoring the status of the room is key to a number of common chat features. For example, you might want to display a warning when the room
has become detached.

### Current status of a room

To get the current status (and error), you can use the `status` property like this:

```swift
switch await room.status {
   case let .failed(error: error):
      // use error
   }
   ...
}
```

### Listening to room status updates

You can also subscribe to changes in the room status and be notified whenever they happen by creating a subscription using the room’s `onStatusChange` method and then iterating over this subscription using its `AsyncSequence` interface:

```swift
let statusSubscription = try await room.onStatusChange()
for await status in statusSubscription {
    print("Room status: \(status)")
}
```

## Handling discontinuity

There may be instances where the connection to Ably is lost for a period of time, for example, when the user enters a tunnel. In many
circumstances, the connection will recover and operation will continue with no discontinuity of messages. However, during extended
periods of disconnection, continuity cannot be guaranteed and you'll need to take steps to recover messages you might have missed.

Each feature of the Chat SDK provides an `onDiscontinuity` method. Here you can create a subscription that will emit a discontinuity event on its `AsyncSequence` interface whenever a
discontinuity in that feature has been observed.

Taking messages as an example, you can listen for discontinuities like so:

```swift
let subscription = room.messages.onDiscontinuity()
for await discontinuityEvent in subscription {
    print("Recovering from the error: \(discontinuityEvent.error)")
}
```

## Chat messages

### Subscribing to incoming messages

To subscribe to incoming messages you create a subscription for the room `messages` object:

```swift
let messagesSubscription = try await room.messages.subscribe()
for await message in messagesSubscription {
    print("Message received: \(message)")
}
```

### Sending messages

To send a message, simply call `send` on the room `messages` property, with the message you want to send:

```swift
let message = try await room.messages.send(params: .init(text: "hello"))
```

### Retrieving message history

The messages object also exposes the `get` method which can be used to request historical messages in the chat room according
to the given criteria. It returns a paginated response that can be used to request more messages:

```swift
let paginatedResult = try await room.messages.get(options: .init(orderBy: .newestFirst))
print(paginatedResult.items)

if paginatedResult.hasNext {
    let next = try await paginatedResult.next!
    print(next.items)
} else {
    print("End of messages")
}
```

### Retrieving message history for a subscribed listener

The return value from `messages.subscribe` includes the `getPreviousMessages`
method, which can be used to request historical messages in the chat room that were sent up to the point that a particular listener was subscribed. It returns a
paginated response that can be used to request for more messages:

```swift
let messagesSubscription = try await room.messages.subscribe()
let paginatedResult = try await messagesSubscription.getPreviousMessages(params: .init(limit: 50)) // `orderBy` here is ignored and always `newestFirst`
print(paginatedResult.items)

if paginatedResult.hasNext {
    let next = try await paginatedResult.next!
    print(next.items)
} else {
    print("End of messages")
}
```

## Online status

### Retrieving online members

You can get the complete list of currently online or present members, their state and data, by calling the `presence.get()` method which returns
a list of the presence messages, where each message contains the most recent data for a member:

```swift
// Retrieve all users entered into presence as an array:
let presentMembers = try await room.presence.get()

// Retrieve the status of specific users by their clientId:
let presentMember = try await room.presence.get(params: .init(clientID: "clemons123"))

// To check whether the user is online or not:
let isPresent = try await room.presence.isUserPresent(clientID: "clemons123")
```

### Entering the presence set

To appear online for other users, you can enter the presence set of a chat room. While entering presence, you can provide optional data that
will be associated with the presence message (can be a nested dictionary):

```swift
try await room.presence.enter(data: ["status": "Online"])
```

### Updating the presence data

Updates allow you to make changes to the custom data associated with a present user. Common use-cases include updating the user's status:

```swift
try await room.presence.update(data: ["status": "Busy"])
```

### Leaving the presence set

Ably automatically triggers a presence leave if a client goes offline. But you can also manually leave the presence set as a result of a UI
action. While leaving presence, you can provide optional data that will be associated with the presence message:

```swift
try await room.presence.leave(data: ["status": "Bye!"])
```

### Subscribing to presence updates

You can create a single subscription for all presence event types:

```swift
let presenceSubscription = try await room.presence.subscribe(events: [.enter, .leave, .update])
for await event in presenceSubscription {
    print("Presence event `\(event.action)` from `\(event.clientId)` with data `\(event.data)`")
}
```

## Typing indicators

> [!NOTE]
> You should be attached to the room to enable this functionality.

Typing events allow you to inform others that a client is typing and also subscribe to others' typing status.

### Retrieving the set of current typers

You can get the complete set of the current typing `clientId`s, by calling the `typing.get` method.

```swift
// Retrieve the entire list of currently typing clients
let currentlyTypingClientIds = try await room.typing.get()
```

### Start typing

To inform other users that you are typing, you can call the start method. This will begin a timer that will automatically stop typing after
a set amount of time.

```swift
try await room.typing.start()
```

Repeated calls to start will reset the timer, so the clients typing status will remain active.

### Stop typing

You can immediately stop typing without waiting for the timer to expire.

```swift
try await room.typing.start()
// Some short delay - timer not yet expired

try await room.typing.stop()
// Timer cleared and stopped typing event emitted and listeners are notified
```

### Subscribing to typing updates

To subscribe to typing events, create a subscription with the `subscribe` method. You can then iterate over it using its `AsyncSequence` interface:

```swift
let typingSubscription = try await room.typing.subscribe()
for await typing in typingSubscription {
    typingInfo = typing.currentlyTyping.isEmpty ? "" : "Typing: \(typing.currentlyTyping.joined(separator: ", "))..."
}
```

## Occupancy of a chat room

Occupancy tells you how many users are connected to the chat room.

### Subscribing to occupancy updates

To subscribe to occupancy updates, create a subscription by calling the `subscribe` method on the chat room’s `occupancy` member. You can then iterate over it using its `AsyncSequence` interface:

```swift
let occupancySubscription = try await room.occupancy.subscribe()
for await event in occupancySubscription {
    occupancyInfo = "Connections: \(event.presenceMembers) (\(event.connections))"
}
```

Occupancy updates are delivered in near-real-time, with updates in quick succession batched together for performance.

### Retrieving the occupancy of a chat room

You can request the current occupancy of a chat room using the `occupancy.get` method:

```swift
let occupancy = try await room.occupancy.get()
```

## Room-level reactions

You can subscribe to and send ephemeral room-level reactions by using the room `reactions` object.
To send room-level reactions, you must be [attached](#attaching-to-a-room) to the room.

### Sending a reaction

To send a reaction such as `like`:

```swift
try await room.reactions.send(params: .init(type: "like"))
```

You can also add any metadata and headers to reactions:

```swift
try await room.reactions.send(params: .init(type: "🎉", metadata: ["effect": "fireworks"]))
```

### Subscribing to room reactions

Subscribe to receive room-level reactions:

```swift
let reactionSubscription = try await room.reactions.subscribe()
for await reaction in reactionSubscription {
    print("Received a reaction of type \(reaction.type), and metadata \(reaction.metadata)")
}
```

## Example app

This repository contains an example app, written using SwiftUI, which demonstrates how to use the SDK. The code for this app is in the [`Example`](Example) directory.

In order to allow the app to use modern SwiftUI features, it supports the following OS versions:

- macOS 14 and above
- iOS 17 and above
- tvOS 17 and above

To run the app, open the `AblyChat.xcworkspace` workspace in Xcode and run the `AblyChatExample` target. If you wish to run it on an iOS or tvOS device, you’ll need to set up code signing.

## In-depth

### Channels Behind Chat Features

It might be useful to know that each feature is backed by an underlying Pub/Sub channel. You can use this information to enable
interoperability with other platforms by subscribing to the channels directly using
the [Ably Pub/Sub SDKs](https://ably.com/docs/products/channels) for those platforms.

The channel for each feature can be obtained via the `channel` property
on that feature.

```swift
let messagesChannel = room.messages.channel
```

**Warning**: You should not attempt to change the state of a channel directly. Doing so may cause unintended side-effects in the Chat SDK.

### Channels Used

For a given chat room, the channels used for features are as follows:

| Feature   | Channel                              |
| --------- | ------------------------------------ |
| Messages  | `<roomId>::$chat::$chatMessages`     |
| Presence  | `<roomId>::$chat::$chatMessages`     |
| Occupancy | `<roomId>::$chat::$chatMessages`     |
| Reactions | `<roomId>::$chat::$reactions`        |
| Typing    | `<roomId>::$chat::$typingIndicators` |

---

## Contributing

For guidance on how to contribute to this project, see the [contributing guidelines](CONTRIBUTING.md).

## Support, feedback and troubleshooting

Please visit http://support.ably.com/ for access to our knowledge base and to ask for any assistance. You can also view
the community reported [Github issues](https://github.com/ably/ably-chat-swift/issues) or raise one yourself.

To see what has changed in recent versions, see the [changelog](CHANGELOG.md).

[Share feedback or request](https://forms.gle/mBw9M53NYuCBLFpMA) a new feature.
