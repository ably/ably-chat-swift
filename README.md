![Ably Chat Swift Header](Images/SwiftChatSDK-github.png)
[![SPM Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fably%2Fably-chat-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ably/ably-chat-swift)
[![License](https://badgen.net/github/license/ably/ably-chat-swift)](https://github.com/ably/ably-chat-swift/blob/main/LICENSE)

---

# Ably Chat Swift SDK

Ably Chat is a set of purpose-built APIs for a host of chat features enabling you to create 1:1, 1:Many, Many:1 and Many:Many chat rooms for any scale. It is designed to meet a wide range of chat use cases, such as livestreams, in-game communication, customer support, or social interactions in SaaS products. Built on [Ably's](https://ably.com/) core service, it abstracts complex details to enable efficient chat architectures.

---

## Getting started

Everything you need to get started with Ably:

- [Getting started with Ably Chat using Swift.](https://ably.com/docs/chat/getting-started/swift)
- [Ably Chat SDK and usage docs in Swift.](https://ably.com/docs/chat/setup?lang=swift)
- Learn [about Ably Chat.](https://ably.com/docs/chat)
- [API documentation.](https://sdk.ably.com/builds/ably/ably-chat-swift/main/AblyChat/documentation/ablychat/)
- [Chat Example App.](https://github.com/ably/ably-chat-swift/tree/main/Example)
- Play with the [livestream chat demo.](https://ably-livestream-chat-demo.vercel.app/)

---

## Supported platforms

Ably aims to support a wide range of platforms. If you experience any compatibility issues, open an issue in the repository or contact [Ably support](https://ably.com/support).

This SDK supports the following platforms:

| Platform | Support |
| -------- | ------- |
| iOS      | >= 14.0 |
| macOS    | >= 11.0 |
| tvOS     | >= 14.0 |

> [!NOTE]
> Xcode 26.0 or later is required.

---

## Installation

The SDK is distributed as a Swift Package and can be installed using Xcode or by adding it as a dependency in your package's `Package.swift`.

#### Using Xcode

To install the `ably-chat-swift` package in your Xcode Project:

1. Open your Xcode project and navigate to **File → Add Package Dependencies...**
2. Paste `https://github.com/ably/ably-chat-swift` in the search box
3. Select the version you want to use
4. Select the Ably Chat SDK for your target

#### Using Swift Package Manager

To install the `ably-chat-swift` package in another Swift Package, add the following to your `Package.swift`:

```swift
.package(url: "https://github.com/ably/ably-chat-swift", from: "1.1.0"),
```

---

## Usage

The following code connects to Ably's chat service, subscribes to a chat room, and sends a message to that room:

```swift
import Ably
import AblyChat

// Initialize Ably Realtime client
let realtimeOptions = ARTClientOptions()
realtimeOptions.key = "<your-ably-api-key>"
realtimeOptions.clientId = "your-client-id"
let realtime = ARTRealtime(options: realtimeOptions)

// Create a chat client
let chatClient = ChatClient(realtime: realtime, clientOptions: ChatClientOptions())

// Get a chat room
let room = try await chatClient.rooms.get(named: "my-room", options: RoomOptions())

// Monitor room status
room.onStatusChange { statusChange in
    switch statusChange.current {
    case .attached:
        print("Room is attached")
    case .detached:
        print("Room is detached")
    case .failed(let error):
        print("Room failed: \(error)")
    default:
        print("Room status: \(statusChange.current)")
    }
}

// Attach to the room
try await room.attach()

// Subscribe to messages
let subscription = room.messages.subscribe { event in
    print("Received message: \(event.message.text)")
}

// Send a message
try await room.messages.send(withParams: SendMessageParams(text: "Hello, World!"))
```

---

## Releases

The [CHANGELOG.md](/CHANGELOG.md) contains details of the latest releases for this SDK. You can also view all Ably releases on [changelog.ably.com](https://changelog.ably.com).

---

## Contribute

Read the [CONTRIBUTING.md](./CONTRIBUTING.md) guidelines to contribute to Ably or [share feedback or request a new feature](https://forms.gle/mBw9M53NYuCBLFpMA).

## Support, feedback and troubleshooting

For help or technical support, visit Ably's [support page](https://ably.com/support). You can also view the [community reported Github issues](https://github.com/ably/ably-chat-swift/issues) or raise one yourself.
