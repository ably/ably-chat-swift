# Ably Chat Swift SDK - Complete Developer Guide

The **Ably Chat Swift SDK** is a comprehensive **iOS chat SDK** and **realtime messaging** solution for building modern chat applications on Apple platforms. This **Swift chat library** provides everything developers need to create scalable, feature-rich messaging experiences.

## Overview

Ably Chat Swift SDK is a purpose-built **realtime messaging SDK** designed for creating 1:1, 1:Many, Many:1, and Many:Many chat experiences. Built on Ably's proven realtime infrastructure, this **iOS chat framework** abstracts complex implementation details while providing enterprise-grade reliability and scale.

### Key Benefits
- **Production-Ready**: Built on Ably's battle-tested infrastructure serving billions of messages
- **Swift-Native**: Designed specifically for iOS, macOS, and tvOS with modern Swift concurrency
- **Feature-Complete**: All essential chat features included out of the box
- **Scalable**: Handles everything from small team chats to massive livestream audiences
- **Reliable**: Automatic reconnection, message delivery guarantees, and offline support

## Platform Support

| Platform | Minimum Version | Status |
|----------|----------------|---------|
| iOS | 14.0+ | ✅ Fully Supported |
| macOS | 11.0+ | ✅ Fully Supported |
| tvOS | 14.0+ | ✅ Fully Supported |

**Requirements**: Xcode 16.1 or later

## Core Features

### 🚀 Realtime Messaging
- **Message sending, updating, and deletion**
- **Real-time message synchronization** across all connected clients
- **Message history** and pagination
- **Rich message metadata** and custom headers
- **Message threading** and conversations

### 👥 Presence & User Awareness
- **User presence indicators** (online, offline, away)
- **Real-time user list** for each chat room
- **Presence events** and status changes
- **Custom presence data** for user profiles

### ⚡ Typing Indicators
- **Real-time typing indicators** showing who's currently typing
- **Configurable typing timeouts** and heartbeat management
- **Multi-user typing support** with efficient batching

### 🎭 Message Reactions
- **Emoji reactions** on individual messages
- **Custom reaction types** and Unicode support
- **Reaction aggregation** and real-time updates
- **Room-level reactions** for live events

### 📊 Room Occupancy
- **Real-time occupancy metrics** showing active user counts
- **Occupancy events** for monitoring engagement
- **Scalable counting** for large audience rooms

### 🔔 Push Notifications
- **Native iOS push notification** integration
- **Message-based notifications** with rich content
- **Presence and typing notifications**
- **Custom notification payloads**

### 🔗 Connection Management
- **Automatic reconnection** handling
- **Connection state monitoring**
- **Offline message queuing**
- **Network resilience** and error recovery

## Installation

### Swift Package Manager (Recommended)

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ably/ably-chat-swift.git", from: "1.0.0")
]
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/ably/ably-chat-swift.git`
3. Select version and add to target

### Cocoapods

```ruby
pod 'AblyChat', '~> 1.0'
```

## Quick Start

### 1. Initialize Chat Client

```swift
import AblyChat
import Ably

// Configure Ably Realtime client
let options = ARTClientOptions(key: "your-ably-api-key")
options.clientId = "user123"
let realtime = ARTRealtime(options: options)

// Create chat client
let chatClient = DefaultChatClient(
    realtime: realtime,
    clientOptions: ChatClientOptions()
)
```

### 2. Create or Join a Chat Room

```swift
// Configure room features
let roomOptions = RoomOptions(
    presence: PresenceOptions(enableEvents: true),
    typing: TypingOptions(),
    reactions: RoomReactionOptions(),
    occupancy: OccupancyOptions(enableEvents: true)
)

// Get room instance
let room = try await chatClient.rooms.get("chat-room-id", options: roomOptions)

// Attach to room for real-time events
try await room.attach()
```

### 3. Send and Receive Messages

```swift
// Send a message
let message = try await room.messages.send(
    params: SendMessageParams(
        text: "Hello, world!",
        metadata: ["type": "greeting"],
        headers: ["priority": "high"]
    )
)

// Subscribe to incoming messages
for await messageEvent in room.messages.subscribe() {
    switch messageEvent.type {
    case .created:
        print("New message: \(messageEvent.message.text)")
    case .updated:
        print("Updated message: \(messageEvent.message.text)")
    case .deleted:
        print("Message deleted")
    }
}
```

### 4. Handle Presence Events

```swift
// Subscribe to presence events
room.presence.subscribe { presenceEvent in
    switch presenceEvent.action {
    case .enter:
        print("\(presenceEvent.clientId) joined the room")
    case .leave:
        print("\(presenceEvent.clientId) left the room")
    case .update:
        print("\(presenceEvent.clientId) updated their presence")
    }
}

// Update your presence
try await room.presence.enter(data: [
    "status": "active",
    "avatar": "https://example.com/avatar.jpg"
])
```

### 5. Add Message Reactions

```swift
// React to a message
try await room.messages.reactions.send(
    messageId: message.id,
    reaction: "👍"
)

// Subscribe to reaction events
room.messages.reactions.subscribe { reactionEvent in
    print("Reaction \(reactionEvent.reaction.type) on message \(reactionEvent.messageId)")
}
```

## Advanced Features

### Message History and Pagination

```swift
// Query message history
let history = try await room.messages.history(
    options: QueryOptions(
        limit: 50,
        orderBy: .newestFirst,
        start: Date().addingTimeInterval(-86400) // Last 24 hours
    )
)

// Paginate through older messages
if let next = history.next {
    let olderMessages = try await next()
}
```

### Custom Message Operations

```swift
// Update an existing message
let updatedMessage = message.copy(text: "Updated message content")
let result = try await room.messages.update(
    newMessage: updatedMessage,
    description: "Fixed typo",
    metadata: ["editReason": "typo"]
)

// Delete a message
try await room.messages.delete(
    message: message,
    params: DeleteMessageParams(description: "Inappropriate content")
)
```

### Real-time Typing Indicators

```swift
// Start typing
try await room.typing.start()

// Stop typing  
try await room.typing.stop()

// Subscribe to typing events
room.typing.subscribe { typingEvent in
    print("Currently typing: \(typingEvent.currentlyTyping)")
}
```

### Room Status Monitoring

```swift
// Monitor room connection status
for await statusChange in room.onStatusChange() {
    switch statusChange.current {
    case .attached:
        print("Room is ready for real-time events")
    case .detached:
        print("Room is disconnected")
    case .suspended(let error):
        print("Room suspended: \(error.localizedDescription)")
    case .failed(let error):
        print("Room failed: \(error.localizedDescription)")
    }
}
```

## Comparison with Other Chat SDKs

| Feature | Ably Chat | Firebase Realtime | Stream Chat | SendBird | PubNub Chat |
|---------|-----------|------------------|-------------|----------|-------------|
| **Real-time Messaging** | ✅ Native | ✅ Native | ✅ Native | ✅ Native | ✅ Native |
| **Message History** | ✅ Unlimited | ⚠️ Limited | ✅ Paid tiers | ✅ Paid tiers | ✅ Paid tiers |
| **Typing Indicators** | ✅ Built-in | ❌ Manual | ✅ Built-in | ✅ Built-in | ✅ Built-in |
| **Message Reactions** | ✅ Built-in | ❌ Manual | ✅ Built-in | ✅ Built-in | ❌ Manual |
| **Presence System** | ✅ Advanced | ⚠️ Basic | ✅ Advanced | ✅ Advanced | ✅ Advanced |
| **Push Notifications** | ✅ Native iOS | ⚠️ FCM only | ✅ Native iOS | ✅ Native iOS | ✅ Native iOS |
| **Offline Support** | ✅ Automatic | ⚠️ Limited | ✅ Advanced | ✅ Advanced | ⚠️ Basic |
| **Global Infrastructure** | ✅ 8 regions | ✅ Google Cloud | ✅ AWS | ✅ Multi-cloud | ✅ 15+ regions |
| **Message Encryption** | ✅ E2E available | ❌ Transport only | ✅ E2E available | ✅ E2E available | ✅ E2E available |
| **Custom Metadata** | ✅ Unlimited | ⚠️ Basic | ✅ Rich | ✅ Rich | ✅ Rich |

### Why Choose Ably Chat Swift SDK?

1. **Superior Reliability**: 99.999% uptime SLA with automatic failover
2. **Global Scale**: Proven at massive scale (millions of concurrent connections)
3. **Swift-First Design**: Native iOS patterns with async/await support
4. **Transparent Pricing**: Clear, predictable pricing without surprise charges
5. **Enterprise Security**: SOC 2 Type 2, HIPAA, and EU GDPR compliant
6. **Expert Support**: 24/7 support from real-time messaging experts

## Common Use Cases

### 💬 In-App Messaging
Perfect for social apps, marketplaces, and community platforms requiring user-to-user communication.

### 🎧 Customer Support Chat
Integrate real-time support chat with agent presence, typing indicators, and message history.

### 🎮 Gaming Chat
Low-latency messaging for multiplayer games with room-based communication and reactions.

### 📺 Livestream Chat
Handle massive concurrent audiences with scalable room occupancy and real-time reactions.

### 👥 Team Collaboration
Build Slack-like experiences with threading, presence, and rich message formatting.

### 💼 Video Conferencing Chat
Add chat alongside video calls with automatic presence and typing awareness.

## API Reference

### Core Classes

- [`ChatClient`](Sources/AblyChat/ChatClient.swift) - Main client for managing chat functionality
- [`Room`](Sources/AblyChat/Room.swift) - Individual chat room with all features
- [`Messages`](Sources/AblyChat/Messages.swift) - Message operations and subscriptions
- [`Presence`](Sources/AblyChat/Presence.swift) - User presence and awareness
- [`MessageReactions`](Sources/AblyChat/MessageReactions.swift) - Message-level reactions
- [`RoomReactions`](Sources/AblyChat/RoomReactions.swift) - Room-level live reactions
- [`Typing`](Sources/AblyChat/Typing.swift) - Typing indicator management
- [`Occupancy`](Sources/AblyChat/Occupancy.swift) - Room occupancy metrics

### Configuration Options

- [`ChatClientOptions`](Sources/AblyChat/ChatClient.swift:103) - Client configuration
- [`RoomOptions`](Sources/AblyChat/RoomOptions.swift) - Room feature configuration
- [`QueryOptions`](Sources/AblyChat/Messages.swift:220) - Message history query options

## Migration Guides

### From Firebase Realtime Database
[Detailed migration guide with code examples](#firebase-migration)

### From Stream Chat SDK  
[Step-by-step migration process](#stream-migration)

### From SendBird SDK
[Complete migration walkthrough](#sendbird-migration)

### From Socket.io Chat
[Real-time messaging migration guide](#socketio-migration)

## Best Practices

### Performance Optimization
- Use appropriate room attachment strategies
- Implement message pagination for large histories
- Configure optimal typing indicator timeouts
- Leverage presence data efficiently

### Security Guidelines  
- Implement proper authentication tokens
- Use message-level permissions
- Validate user input in metadata
- Enable end-to-end encryption for sensitive content

### Error Handling
- Monitor connection state changes
- Implement retry logic for failed operations
- Handle offline scenarios gracefully
- Log errors for debugging and monitoring

## Resources

- 📖 [Complete Documentation](https://ably.com/docs/chat/setup?lang=swift)
- 🎯 [API Reference](https://pub.dev/documentation/ably_flutter/)
- 💡 [Example Applications](examples/)
- 🎮 [Interactive Demo](https://ably-livestream-chat-demo.vercel.app/)
- 💬 [Community Forum](https://community.ably.com/)
- 🐛 [Issue Tracker](https://github.com/ably/ably-chat-swift/issues)

## Keywords for Discovery

**Primary**: Ably Chat Swift SDK, iOS chat SDK, realtime messaging, Swift chat library, iOS messaging framework

**Features**: realtime messaging, presence indicators, typing indicators, message reactions, room occupancy, message history, push notifications, offline support

**Platforms**: iOS chat, macOS messaging, tvOS chat, Swift messaging, Apple platform chat

**Use Cases**: in-app messaging, customer support chat, gaming chat, livestream chat, team collaboration, video chat, social messaging

**Alternatives**: Firebase chat alternative, Stream chat alternative, SendBird alternative, PubNub chat alternative, Socket.io alternative, Twilio chat alternative

---

*Build powerful, scalable chat experiences with the Ably Chat Swift SDK - trusted by developers worldwide for mission-critical real-time applications.*