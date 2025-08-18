# Ably Chat Swift SDK - API Reference Summary

This high-level API reference provides an overview of all **core classes**, **protocols**, **methods**, and **data structures** in the **Ably Chat Swift SDK** for **iOS chat applications** and **realtime messaging**.

## Table of Contents

- [Core Classes](#core-classes)
- [Room Features](#room-features)
- [Data Structures](#data-structures)
- [Configuration Options](#configuration-options)
- [Event Types](#event-types)
- [Subscription Patterns](#subscription-patterns)
- [Error Handling](#error-handling)
- [Quick Reference](#quick-reference)

---

## Core Classes

### [`ChatClient`](Sources/AblyChat/ChatClient.swift:4)

**Main entry point for the Ably Chat SDK**

```swift
@MainActor
public protocol ChatClient: AnyObject, Sendable {
    // Properties
    var rooms: any Rooms { get }
    var connection: any Connection { get }
    var clientID: String { get }
    var realtime: RealtimeClient { get }
    var clientOptions: ChatClientOptions { get }
}
```

**Usage:**
```swift
let chatClient = DefaultChatClient(
    realtime: realtime,
    clientOptions: ChatClientOptions()
)
```

**Key Features:**
- ✅ **Room management** via [`rooms`](Sources/AblyChat/ChatClient.swift:10) property
- ✅ **Connection monitoring** via [`connection`](Sources/AblyChat/ChatClient.swift:18) property  
- ✅ **Client identification** via [`clientID`](Sources/AblyChat/ChatClient.swift:25) property
- ✅ **Underlying Ably SDK** access via [`realtime`](Sources/AblyChat/ChatClient.swift:32) property

---

### [`Room`](Sources/AblyChat/Room.swift:7)

**Represents a chat room with all messaging features**

```swift
@MainActor
public protocol Room: AnyObject, Sendable {
    // Core Properties
    var name: String { get }
    var status: RoomStatus { get }
    var options: RoomOptions { get }
    
    // Feature Interfaces
    var messages: any Messages { get }
    var presence: any Presence { get }
    var reactions: any RoomReactions { get }
    var typing: any Typing { get }
    var occupancy: any Occupancy { get }
    
    // Lifecycle Methods
    func attach() async throws(ARTErrorInfo)
    func detach() async throws(ARTErrorInfo)
    
    // Status Monitoring
    func onStatusChange(_ callback: @escaping (RoomStatusChange) -> Void) -> StatusSubscriptionProtocol
    func onDiscontinuity(_ callback: @escaping (DiscontinuityEvent) -> Void) -> StatusSubscriptionProtocol
}
```

**Key Features:**
- ✅ **Real-time messaging** via [`messages`](Sources/AblyChat/Room.swift:20)
- ✅ **User presence** via [`presence`](Sources/AblyChat/Room.swift:29)
- ✅ **Live reactions** via [`reactions`](Sources/AblyChat/Room.swift:38)
- ✅ **Typing indicators** via [`typing`](Sources/AblyChat/Room.swift:47)
- ✅ **Occupancy metrics** via [`occupancy`](Sources/AblyChat/Room.swift:56)
- ✅ **Lifecycle management** with [`attach()`](Sources/AblyChat/Room.swift:99)/[`detach()`](Sources/AblyChat/Room.swift:106)

---

## Room Features

### [`Messages`](Sources/AblyChat/Messages.swift:10)

**Real-time messaging with CRUD operations**

```swift
@MainActor
public protocol Messages: AnyObject, Sendable {
    // Message Operations
    func send(params: SendMessageParams) async throws(ARTErrorInfo) -> Message
    func update(newMessage: Message, description: String?, metadata: OperationMetadata?) async throws(ARTErrorInfo) -> Message
    func delete(message: Message, params: DeleteMessageParams) async throws(ARTErrorInfo) -> Message
    
    // Message History
    func history(options: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>
    
    // Real-time Subscriptions
    func subscribe(_ callback: @escaping (ChatMessageEvent) -> Void) -> MessageSubscriptionResponseProtocol
    func subscribe() -> MessageSubscriptionAsyncSequence
    
    // Message Reactions
    var reactions: MessageReactions { get }
}
```

**Key Methods:**
- [`send(params:)`](Sources/AblyChat/Messages.swift:43) - Send new messages
- [`update(newMessage:description:metadata:)`](Sources/AblyChat/Messages.swift:59) - Update existing messages
- [`delete(message:params:)`](Sources/AblyChat/Messages.swift:74) - Delete messages
- [`history(options:)`](Sources/AblyChat/Messages.swift:29) - Query message history
- [`subscribe()`](Sources/AblyChat/Messages.swift:115) - Real-time message events

---

### [`Presence`](Sources/AblyChat/Presence.swift:12)

**User presence and awareness system**

```swift
@MainActor
public protocol Presence: AnyObject, Sendable {
    // Presence Operations
    func enter(data: PresenceData) async throws(ARTErrorInfo)
    func update(data: PresenceData) async throws(ARTErrorInfo)
    func leave(data: PresenceData) async throws(ARTErrorInfo)
    func enter() async throws(ARTErrorInfo)
    func update() async throws(ARTErrorInfo)
    func leave() async throws(ARTErrorInfo)
    
    // Presence Queries
    func get() async throws(ARTErrorInfo) -> [PresenceMember]
    func get(params: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember]
    func isUserPresent(clientID: String) async throws(ARTErrorInfo) -> Bool
    
    // Presence Events
    func subscribe(event: PresenceEventType, _ callback: @escaping (PresenceEvent) -> Void) -> SubscriptionProtocol
    func subscribe(events: [PresenceEventType], _ callback: @escaping (PresenceEvent) -> Void) -> SubscriptionProtocol
}
```

**Key Methods:**
- [`enter(data:)`](Sources/AblyChat/Presence.swift:50)/[`enter()`](Sources/AblyChat/Presence.swift:106) - Join room presence
- [`update(data:)`](Sources/AblyChat/Presence.swift:60)/[`update()`](Sources/AblyChat/Presence.swift:114) - Update presence data
- [`leave(data:)`](Sources/AblyChat/Presence.swift:70)/[`leave()`](Sources/AblyChat/Presence.swift:122) - Leave room presence
- [`get(params:)`](Sources/AblyChat/Presence.swift:28) - Get current presence members
- [`subscribe(events:)`](Sources/AblyChat/Presence.swift:98) - Subscribe to presence events

---

### [`Typing`](Sources/AblyChat/Typing.swift:10)

**Real-time typing indicators**

```swift
@MainActor
public protocol Typing: AnyObject, Sendable {
    // Typing Operations
    func keystroke() async throws(ARTErrorInfo)
    func stop() async throws(ARTErrorInfo)
    
    // Typing State
    func get() async throws(ARTErrorInfo) -> Set<String>
    
    // Typing Events
    func subscribe(_ callback: @escaping (TypingSetEvent) -> Void) -> SubscriptionProtocol
    func subscribe() -> SubscriptionAsyncSequence<TypingSetEvent>
}
```

**Key Methods:**
- [`keystroke()`](Sources/AblyChat/Typing.swift:40) - Indicate user is typing
- [`stop()`](Sources/AblyChat/Typing.swift:48) - Stop typing indicator
- [`get()`](Sources/AblyChat/Typing.swift:27) - Get current typing users
- [`subscribe()`](Sources/AblyChat/Typing.swift:78) - Subscribe to typing events

---

### [`MessageReactions`](Sources/AblyChat/MessageReactions.swift:9)

**Message-level reactions and emoji responses**

```swift
@MainActor
public protocol MessageReactions: AnyObject, Sendable {
    // Reaction Operations
    func send(to messageSerial: String, params: SendMessageReactionParams) async throws(ARTErrorInfo)
    func delete(from messageSerial: String, params: DeleteMessageReactionParams) async throws(ARTErrorInfo)
    
    // Reaction Events
    func subscribe(_ callback: @escaping (MessageReactionSummaryEvent) -> Void) -> SubscriptionProtocol
    func subscribeRaw(_ callback: @escaping (MessageReactionRawEvent) -> Void) -> SubscriptionProtocol
    func subscribe() -> SubscriptionAsyncSequence<MessageReactionSummaryEvent>
}
```

**Key Methods:**
- [`send(to:params:)`](Sources/AblyChat/MessageReactions.swift:19) - Add message reaction
- [`delete(from:params:)`](Sources/AblyChat/MessageReactions.swift:28) - Remove message reaction
- [`subscribe()`](Sources/AblyChat/MessageReactions.swift:82) - Subscribe to reaction summaries
- [`subscribeRaw()`](Sources/AblyChat/MessageReactions.swift:111) - Subscribe to raw reaction events

---

### [`RoomReactions`](Sources/AblyChat/RoomReactions.swift:9)

**Room-level live reactions for events and streams**

```swift
@MainActor
public protocol RoomReactions: AnyObject, Sendable {
    // Room Reaction Operations
    func send(params: SendReactionParams) async throws(ARTErrorInfo)
    
    // Room Reaction Events
    func subscribe(_ callback: @escaping (RoomReactionEvent) -> Void) -> SubscriptionProtocol
    func subscribe() -> SubscriptionAsyncSequence<RoomReactionEvent>
}
```

**Key Methods:**
- [`send(params:)`](Sources/AblyChat/RoomReactions.swift:18) - Send room-level reaction
- [`subscribe()`](Sources/AblyChat/RoomReactions.swift:58) - Subscribe to room reactions

---

### [`Occupancy`](Sources/AblyChat/Occupancy.swift:10)

**Room occupancy metrics and audience insights**

```swift
@MainActor
public protocol Occupancy: AnyObject, Sendable {
    // Occupancy Data
    func get() async throws(ARTErrorInfo) -> OccupancyData
    
    // Occupancy Events
    func subscribe(_ callback: @escaping (OccupancyEvent) -> Void) -> SubscriptionProtocol
    func subscribe() -> SubscriptionAsyncSequence<OccupancyEvent>
}
```

**Key Methods:**
- [`get()`](Sources/AblyChat/Occupancy.swift:29) - Get current occupancy metrics
- [`subscribe()`](Sources/AblyChat/Occupancy.swift:61) - Subscribe to occupancy updates

---

## Data Structures

### [`Message`](Sources/AblyChat/Message.swift:22)

**Core message data structure**

```swift
public struct Message: Sendable, Identifiable, Equatable {
    // Identity
    public var id: String { serial }
    public var serial: String
    public var version: String
    
    // Content
    public var text: String
    public var action: MessageAction
    public var clientID: String
    
    // Timestamps
    public var createdAt: Date?
    public var timestamp: Date?
    
    // Rich Content
    public var metadata: MessageMetadata
    public var headers: MessageHeaders
    
    // Operations & Reactions
    public var operation: MessageOperation?
    public var reactions: MessageReactionSummary?
    
    // Helper Methods
    func copy(text: String?, metadata: MessageMetadata?, headers: MessageHeaders?, reactions: MessageReactionSummary?) -> Message
}
```

### [`PresenceMember`](Sources/AblyChat/Presence.swift:194)

**Presence member data structure**

```swift
public struct PresenceMember: Sendable {
    public var clientID: String
    public var data: PresenceData?
    public var extras: [String: JSONValue]?
    public var updatedAt: Date
}
```

### [`OccupancyData`](Sources/AblyChat/Occupancy.swift:69)

**Room occupancy metrics**

```swift
public struct OccupancyData: Sendable {
    public var connections: Int        // Total connections
    public var presenceMembers: Int   // Active presence members
}
```

---

## Configuration Options

### [`ChatClientOptions`](Sources/AblyChat/ChatClient.swift:103)

**Client-level configuration**

```swift
public struct ChatClientOptions: Sendable {
    public var logHandler: LogHandler?
    public var logLevel: LogLevel?
}
```

### [`RoomOptions`](Sources/AblyChat/RoomOptions.swift:6)

**Room feature configuration**

```swift
public struct RoomOptions: Sendable, Equatable {
    public var presence = PresenceOptions()      // Presence configuration
    public var typing = TypingOptions()          // Typing configuration  
    public var reactions = RoomReactionsOptions()// Reactions configuration
    public var occupancy = OccupancyOptions()    // Occupancy configuration
    public var messages = MessagesOptions()      // Messages configuration
}
```

### Feature-Specific Options

**[`PresenceOptions`](Sources/AblyChat/RoomOptions.swift:44):**
```swift
public struct PresenceOptions: Sendable, Equatable {
    public var enableEvents = true  // Enable presence event subscriptions
}
```

**[`TypingOptions`](Sources/AblyChat/RoomOptions.swift:92):**
```swift
public struct TypingOptions: Sendable, Equatable {
    public var heartbeatThrottle: TimeInterval = 10  // Typing heartbeat interval
}
```

**[`MessagesOptions`](Sources/AblyChat/RoomOptions.swift:62):**
```swift
public struct MessagesOptions: Sendable, Equatable {
    public var rawMessageReactions = false                           // Enable raw reactions
    public var defaultMessageReactionType = MessageReactionType.distinct  // Default reaction type
}
```

**[`OccupancyOptions`](Sources/AblyChat/RoomOptions.swift:120):**
```swift
public struct OccupancyOptions: Sendable, Equatable {
    public var enableEvents = false  // Enable occupancy event subscriptions
}
```

---

## Event Types

### Message Events

**[`ChatMessageEvent`](Sources/AblyChat/Messages.swift:309):**
```swift
public struct ChatMessageEvent: Sendable, Equatable {
    public let type: ChatMessageEventType  // .created, .updated, .deleted
    public let message: Message
}
```

### Presence Events

**[`PresenceEvent`](Sources/AblyChat/Presence.swift:261):**
```swift
public struct PresenceEvent: Sendable {
    public var type: PresenceEventType  // .enter, .leave, .update, .present
    public var member: PresenceMember
}
```

### Typing Events

**[`TypingSetEvent`](Sources/AblyChat/Typing.swift:86):**
```swift
public struct TypingSetEvent: Sendable {
    public var type: TypingSetEventType
    public var currentlyTyping: Set<String>
    public var change: Change  // Who started/stopped typing
}
```

### Reaction Events

**[`RoomReactionEvent`](Sources/AblyChat/RoomReactions.swift:114):**
```swift
public struct RoomReactionEvent: Sendable {
    public let type: RoomReactionEventType  // .reaction
    public let reaction: RoomReaction
}
```

### Occupancy Events

**[`OccupancyEvent`](Sources/AblyChat/Occupancy.swift:91):**
```swift
public struct OccupancyEvent: Sendable {
    public let type: OccupancyEventType  // .updated
    public let occupancy: OccupancyData
}
```

---

## Subscription Patterns

### Callback-based Subscriptions

```swift
// Message subscriptions
let subscription = room.messages.subscribe { messageEvent in
    print("New message: \(messageEvent.message.text)")
}

// Presence subscriptions
let presenceSubscription = room.presence.subscribe(events: [.enter, .leave]) { presenceEvent in
    print("Presence change: \(presenceEvent.type)")
}

// Unsubscribe when done
subscription.unsubscribe()
presenceSubscription.unsubscribe()
```

### AsyncSequence Subscriptions

```swift
// Message async sequence
for await messageEvent in room.messages.subscribe() {
    switch messageEvent.type {
    case .created:
        handleNewMessage(messageEvent.message)
    case .updated:
        updateMessage(messageEvent.message)
    case .deleted:
        removeMessage(messageEvent.message)
    }
}

// Presence async sequence
for await presenceEvent in room.presence.subscribe(events: [.enter, .leave]) {
    updateUserList(presenceEvent.member)
}

// Typing async sequence
for await typingEvent in room.typing.subscribe() {
    updateTypingIndicator(typingEvent.currentlyTyping)
}
```

### Room Status Monitoring

```swift
// Room status changes
for await statusChange in room.onStatusChange() {
    switch statusChange.current {
    case .attached:
        print("Room ready")
    case .detached:
        print("Room disconnected")
    case .suspended(let error):
        print("Room suspended: \(error)")
    case .failed(let error):
        print("Room failed: \(error)")
    }
}
```

---

## Error Handling

### Standard Error Types

All async methods throw `ARTErrorInfo` for consistent error handling:

```swift
do {
    let message = try await room.messages.send(
        params: SendMessageParams(text: "Hello!")
    )
} catch let error as ARTErrorInfo {
    print("Error: \(error.message)")
    print("Code: \(error.code)")
}
```

### Connection Error Monitoring

```swift
// Monitor connection status
for await connectionChange in chatClient.connection.onStatusChange() {
    switch connectionChange.current {
    case .connected:
        print("Connected to Ably")
    case .disconnected:
        print("Disconnected")
    case .failed(let error):
        print("Connection failed: \(error)")
    }
}
```

---

## Quick Reference

### Basic Setup

```swift
// 1. Initialize Ably Realtime
let options = ARTClientOptions(key: "your-api-key")
options.clientId = "user123"
let realtime = ARTRealtime(options: options)

// 2. Create Chat Client
let chatClient = DefaultChatClient(
    realtime: realtime,
    clientOptions: ChatClientOptions()
)

// 3. Get Room
let roomOptions = RoomOptions(
    presence: PresenceOptions(enableEvents: true),
    typing: TypingOptions(),
    occupancy: OccupancyOptions(enableEvents: true)
)
let room = try await chatClient.rooms.get("my-room", options: roomOptions)

// 4. Attach to Room
try await room.attach()
```

### Common Operations

```swift
// Send message
let message = try await room.messages.send(
    params: SendMessageParams(
        text: "Hello world!",
        metadata: ["type": "greeting"]
    )
)

// Enter presence
try await room.presence.enter(data: [
    "status": "online",
    "displayName": "John Doe"
])

// Start typing
try await room.typing.keystroke()

// Add reaction
try await room.messages.reactions.send(
    to: message.serial,
    params: SendMessageReactionParams(name: "👍")
)

// Send room reaction
try await room.reactions.send(
    params: SendReactionParams(name: "🎉")
)
```

### Query Operations

```swift
// Get message history
let history = try await room.messages.history(
    options: QueryOptions(
        limit: 50,
        orderBy: .newestFirst
    )
)

// Get presence members
let members = try await room.presence.get()

// Get current typers
let typers = try await room.typing.get()

// Get occupancy metrics
let occupancy = try await room.occupancy.get()
print("Connections: \(occupancy.connections)")
print("Presence members: \(occupancy.presenceMembers)")
```

---

## Type Aliases

### Common Types

```swift
// Message-related types
public typealias MessageHeaders = Headers
public typealias MessageMetadata = Metadata
public typealias OperationMetadata = Metadata

// Presence-related types  
public typealias PresenceData = JSONValue

// Reaction-related types
public typealias ReactionMetadata = Metadata
public typealias ReactionHeaders = Headers

// Client types
public typealias RealtimeClient = any RealtimeClientProtocol
```

### Query and Parameter Types

```swift
// Message parameters
SendMessageParams(text: String, metadata: MessageMetadata?, headers: MessageHeaders?)
UpdateMessageParams(message: SendMessageParams, description: String?, metadata: OperationMetadata?)
DeleteMessageParams(description: String?, metadata: OperationMetadata?)

// Query parameters
QueryOptions(start: Date?, end: Date?, limit: Int?, orderBy: OrderBy?)
PresenceParams(clientID: String?, connectionID: String?, waitForSync: Bool)

// Reaction parameters
SendMessageReactionParams(name: String, type: MessageReactionType?, count: Int?)
DeleteMessageReactionParams(name: String?, type: MessageReactionType?)
SendReactionParams(name: String, metadata: ReactionMetadata?, headers: ReactionHeaders?)
```

---

## Platform Requirements

- **iOS**: 14.0+
- **macOS**: 11.0+  
- **tvOS**: 14.0+
- **Xcode**: 16.1+
- **Swift**: 6.0+

---

*This API summary covers the essential interfaces and usage patterns. For detailed implementation examples, see the [examples/](examples/) directory and [comprehensive documentation](https://ably.com/docs/chat/setup?lang=swift).*