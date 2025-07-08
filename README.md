# Ably Chat SDK for Swift

<p style="text-align: left">
    <img src="https://badgen.net/github/license/3scale/saas-operator" alt="License" />
    <img alt="GitHub Release" src="https://img.shields.io/github/v/release/ably/ably-chat-swift">
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

Xcode 16.1 or later.

## Installation

The SDK is distributed as a Swift package and can hence be installed using Xcode (search for `github.com/ably/ably-chat-swift` package) or by adding it as a dependency in your package’s `Package.swift`:

```swift
.package(url: "https://github.com/ably/ably-chat-swift", from: "0.5.0")
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

## Getting Started

At the end of this tutorial, you will have initialized the Ably Chat client and sent your first message.

First of all, start by creating a Swift project and installing the Chat SDK using the instructions described above. Next, replace the contents of your `main.swift` file with
the following code. This simple script initializes the Chat client, creates a chat room and sends a message, printing it to the console when it is received over the websocket connection.

```swift
import Ably
import AblyChat
import Foundation

// Create the Ably Realtime client using your API key and use that to instantiate the Ably Chat client.
// You can re-use these clients for the duration of your application
let realtimeOptions = ARTClientOptions()
realtimeOptions.key = "<API_KEY>"
realtimeOptions.clientId = "ably-chat"
let realtime = ARTRealtime(options: realtimeOptions)
let chatClient = DefaultChatClient(realtime: realtime, clientOptions: nil)

// Subscribe to connection state changes
let connectionStateSubscription = chatClient.connection.onStatusChange()
Task {
    for await stateChange in connectionStateSubscription {
        print("Connection status changed: \(stateChange.current)")
    }
}

// Get a chat room for the tutorial
let room = try await chatClient.rooms.get(
    name: "readme-getting-started")

// Add a listener to observe changes to the chat rooms status
let statusSubscription = room.onStatusChange()
Task {
    for await status in statusSubscription {
        print("Room status changed: \(status.current)")
    }
}

// Attach the chat room - this means we will begin to receive messages from the server
try await room.attach()

// Add a listener for new messages in the chat room
let messagesSubscription = try await room.messages.subscribe()
Task {
    // Subscribe to messages
    for await message in messagesSubscription {
        print("Message received: \(message.text)")
    }
}

// Send a message
_ = try await room.messages.send(
    params: .init(text: "Hello, World! This is my first message with Ably Chat!"))

// Wait 5 seconds before closing the connection so we have plenty of time to receive the message we just sent
// This disconnects the client from Ably servers
try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
await chatClient.rooms.release(name: "readme-getting-started")
realtime.close()
print("Connection closed")
```

Now run your script:

```shell
swift run
```

All being well, you should now see the following in your terminal:

```
Room status changed: attaching(error: nil)
Connection status changed: connected
Room status changed: attached
Message received: Hello, World! This is my first message with Ably Chat!
Room status changed: releasing
Room status changed: released
Connection closed
```

Congratulations! You have sent your first message using the Ably Chat SDK!

## Example app

This repository contains an example app, written using SwiftUI, which demonstrates how to use the SDK. The code for this app is in the [`Example`](Example) directory.

In order to allow the app to use modern SwiftUI features, it supports the following OS versions:

- macOS 14 and above
- iOS 17 and above
- tvOS 17 and above

To run the app, open the `AblyChat.xcworkspace` workspace in Xcode and run the `AblyChatExample` target. If you wish to run it on an iOS or tvOS device, you’ll need to set up code signing.

## Contributing

For guidance on how to contribute to this project, see the [contributing guidelines](CONTRIBUTING.md).

## Support, feedback and troubleshooting

Please visit http://support.ably.com/ for access to our knowledge base and to ask for any assistance. You can also view
the community reported [Github issues](https://github.com/ably/ably-chat-swift/issues) or raise one yourself.

To see what has changed in recent versions, see the [changelog](CHANGELOG.md).

[Share feedback or request](https://forms.gle/mBw9M53NYuCBLFpMA) a new feature.
