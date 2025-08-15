# Ably Chat Swift SDK - Frequently Asked Questions

This comprehensive FAQ covers the most common questions about integrating and using the **Ably Chat Swift SDK** for **iOS chat applications**, **realtime messaging**, and **Swift chat development**.

## Table of Contents

- [Getting Started](#getting-started)
- [Installation & Setup](#installation--setup)
- [Platform Compatibility](#platform-compatibility)
- [Features & Capabilities](#features--capabilities)
- [Integration Questions](#integration-questions)
- [Troubleshooting](#troubleshooting)
- [Performance & Scaling](#performance--scaling)
- [Pricing & Limits](#pricing--limits)
- [Migration from Other SDKs](#migration-from-other-sdks)
- [Security & Compliance](#security--compliance)
- [Advanced Usage](#advanced-usage)

---

## Getting Started

### What is the Ably Chat Swift SDK?

The **Ably Chat Swift SDK** is a comprehensive **iOS chat framework** that provides everything needed to build **realtime messaging applications** on Apple platforms. It's built on top of Ably's proven realtime infrastructure and offers features like real-time messaging, presence indicators, typing awareness, message reactions, and push notifications.

### Who should use this SDK?

- **iOS developers** building chat applications
- **Swift developers** creating messaging features
- **Product teams** needing reliable, scalable chat
- **Enterprise developers** requiring production-ready messaging
- **Mobile app developers** adding social or collaborative features

### What makes Ably Chat different from other chat SDKs?

- **Production-ready**: Built on Ably's battle-tested infrastructure
- **Swift-native**: Designed specifically for iOS with modern async/await
- **Feature-complete**: All essential chat features included
- **Globally distributed**: 8+ regions with 99.999% uptime SLA
- **Transparent pricing**: No surprise charges or hidden costs

### How quickly can I integrate chat into my app?

With the Ably Chat Swift SDK, you can have basic chat functionality running in **under 30 minutes**:

1. Add the dependency (2 minutes)
2. Initialize the client (5 minutes)  
3. Create a room and send messages (10 minutes)
4. Add basic UI (15 minutes)

---

## Installation & Setup

### How do I install the Ably Chat Swift SDK?

**Swift Package Manager (Recommended):**
```swift
dependencies: [
    .package(url: "https://github.com/ably/ably-chat-swift.git", from: "0.7.0")
]
```

**CocoaPods:**
```ruby
pod 'AblyChat', '~> 0.7'
```

**Xcode GUI:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/ably/ably-chat-swift.git`
3. Select version and add to target

### Do I need an Ably account to get started?

Yes, you need an [Ably account](https://ably.com/signup) to get your API key. However:

- **Free tier available** with generous limits
- **No credit card required** for development
- **Sandbox environment** for testing
- **Production keys** when you're ready to launch

### What's the minimum setup required?

```swift
import AblyChat
import Ably

// 1. Configure Ably Realtime
let options = ARTClientOptions(key: "your-api-key")
options.clientId = "user123"
let realtime = ARTRealtime(options: options)

// 2. Create chat client
let chatClient = DefaultChatClient(
    realtime: realtime,
    clientOptions: ChatClientOptions()
)

// 3. Get a room and start chatting
let room = try await chatClient.rooms.get("my-room")
try await room.attach()
```

### How do I handle API keys securely?

**Never hardcode API keys in your app.** Instead:

1. **Use environment variables** during development
2. **Server-side token generation** for production
3. **Ably Token Authentication** for client apps
4. **Capability-restricted tokens** for security

```swift
// Use token authentication (recommended)
let options = ARTClientOptions()
options.useTokenAuth = true
options.authUrl = URL(string: "https://yourserver.com/auth")
```

---

## Platform Compatibility

### Which Apple platforms are supported?

| Platform | Minimum Version | Status |
|----------|----------------|---------|
| iOS      | 14.0+          | ✅ Full Support |
| macOS    | 11.0+          | ✅ Full Support |  
| tvOS     | 14.0+          | ✅ Full Support |

**Requirements**: Xcode 16.1 or later, Swift 6.0+

### Does it work with SwiftUI and UIKit?

**Yes, both!** The SDK is framework-agnostic:

- **SwiftUI**: Native async/await integration with `@State` and `@Published`
- **UIKit**: Traditional callback and delegate patterns
- **Combine**: Publisher-based reactive programming
- **Mixed projects**: Use in hybrid SwiftUI/UIKit apps

### Is watchOS supported?

**Not currently.** The SDK focuses on iOS, macOS, and tvOS. WatchOS support may be added in future versions based on demand.

### What about Catalyst apps?

**Mac Catalyst apps work** through the macOS target. The SDK runs natively on both Intel and Apple Silicon Macs.

### Can I use this in an app extension?

**Limited support.** The SDK works in app extensions but with restrictions:
- Network extensions: ✅ Yes
- Today extensions: ⚠️ Limited (background restrictions)
- Share extensions: ✅ Yes  
- Notification extensions: ⚠️ Limited

---

## Features & Capabilities

### What chat features are included?

**Core Messaging:**
- ✅ Send, edit, delete messages
- ✅ Real-time message synchronization
- ✅ Message history with pagination
- ✅ Rich metadata and headers
- ✅ Message threading support

**Social Features:**
- ✅ User presence indicators
- ✅ Typing indicators
- ✅ Message reactions (emoji + custom)
- ✅ Room-level live reactions
- ✅ Room occupancy metrics

**Infrastructure:**
- ✅ Automatic reconnection
- ✅ Offline message queuing  
- ✅ Connection state management
- ✅ Push notifications
- ✅ Multi-room coordination

### Does it support file sharing?

**Not directly**, but you can implement file sharing by:

1. **Upload files** to your storage service (S3, CloudKit, etc.)
2. **Send URLs** as message content with metadata
3. **Rich message rendering** in your UI
4. **Progress tracking** for uploads/downloads

```swift
// Example: Send image message
let message = try await room.messages.send(
    params: SendMessageParams(
        text: "Shared a photo",
        metadata: [
            "type": "image",
            "url": "https://your-cdn.com/image.jpg",
            "filename": "vacation.jpg",
            "size": 1024000
        ]
    )
)
```

### Can I create private 1:1 conversations?

**Yes!** Create rooms with unique IDs for private chats:

```swift
// Generate unique room ID for 1:1 chat
let roomId = "\(user1Id)-\(user2Id)".sorted().joined(separator: "-")
let privateRoom = try await chatClient.rooms.get(roomId)
```

### Does it support message encryption?

**Yes, with Ably's encryption features:**

- **Transport encryption**: TLS by default
- **End-to-end encryption**: Available with client-side keys
- **Channel encryption**: Encrypt specific rooms

```swift
// Enable encryption for sensitive conversations
let roomOptions = RoomOptions()
roomOptions.encryption = EncryptionOptions(key: yourEncryptionKey)
let room = try await chatClient.rooms.get("secure-room", options: roomOptions)
```

### Are push notifications supported?

**Yes, full iOS push notification support:**

- ✅ Native iOS notifications with rich content
- ✅ Custom notification categories and actions
- ✅ Quick reply from notifications
- ✅ Badge count management
- ✅ Background notification handling

### Can I moderate content?

**Yes, several moderation approaches:**

1. **Client-side**: Filter/block before sending
2. **Server-side**: Use Ably's webhook integrations
3. **Message updates**: Edit inappropriate content
4. **Message deletion**: Remove violations
5. **User permissions**: Role-based access control

---

## Integration Questions

### How do I handle user authentication?

The SDK integrates with your existing authentication system:

```swift
// After user logs in to your system
let options = ARTClientOptions()
options.clientId = currentUser.id
options.authUrl = URL(string: "https://yourapi.com/ably-auth")

// Your server generates Ably tokens for authenticated users
let realtime = ARTRealtime(options: options)
let chatClient = DefaultChatClient(realtime: realtime)
```

### Can I customize the UI completely?

**Yes, complete UI control.** The SDK only provides data and events:

- **Headless SDK**: No UI components included
- **Data-driven**: React to events and state changes  
- **Flexible rendering**: Use any UI framework or custom views
- **Theme-agnostic**: Fits any design system

### How do I handle offline users?

**Built-in offline support:**

1. **Automatic queuing**: Messages queued when offline
2. **Reconnection handling**: Auto-reconnect with backoff
3. **State synchronization**: Catch up on missed events
4. **UI feedback**: Connection status indicators

```swift
// Monitor connection state
for await statusChange in chatClient.connection.onStatusChange() {
    switch statusChange.current {
    case .connected:
        flushOfflineQueue()
    case .disconnected:
        enableOfflineMode()
    }
}
```

### Can I integrate with existing databases?

**Yes, common patterns:**

1. **Message storage**: Sync Ably messages to your database
2. **User profiles**: Combine Ably presence with your user data
3. **Analytics**: Track message events in your analytics
4. **Search**: Index messages for full-text search

```swift
// Sync messages to local database
for await messageEvent in room.messages.subscribe() {
    switch messageEvent.type {
    case .created:
        localDatabase.save(messageEvent.message)
    case .updated:
        localDatabase.update(messageEvent.message)
    case .deleted:
        localDatabase.delete(messageEvent.message.id)
    }
}
```

### How do I implement message threading?

**Using message metadata:**

```swift
// Reply to a message
let replyMessage = try await room.messages.send(
    params: SendMessageParams(
        text: "This is a reply",
        metadata: [
            "threadId": originalMessage.id,
            "replyToMessageId": originalMessage.id,
            "threadType": "reply"
        ]
    )
)

// Query thread messages
let threadMessages = try await room.messages.history(
    options: QueryOptions(
        where: ["metadata.threadId": originalMessage.id],
        orderBy: .oldestFirst
    )
)
```

---

## Troubleshooting

### Why am I getting connection errors?

**Common causes and solutions:**

1. **Invalid API Key**
   ```swift
   // Check your API key format
   let options = ARTClientOptions(key: "app.key:secret")
   // Not: ARTClientOptions(key: "just-the-secret")
   ```

2. **Network restrictions**
   - Check firewall settings
   - Ensure WebSocket connections allowed
   - Verify TLS 1.2+ support

3. **Token expiration**
   ```swift
   // Implement token refresh
   options.authCallback = { tokenParams, completion in
       // Fetch fresh token from your server
   }
   ```

### Messages aren't appearing in real-time

**Troubleshooting checklist:**

1. **Room attachment**: Ensure room is attached
   ```swift
   if room.status != .attached {
       try await room.attach()
   }
   ```

2. **Subscription active**: Check message subscription
   ```swift
   // Verify subscription is active
   let subscription = room.messages.subscribe { message in
       print("Received: \(message)")
   }
   ```

3. **Connection state**: Verify client is connected
4. **Capability restrictions**: Check token permissions

### High memory usage or battery drain?

**Optimization strategies:**

1. **Detach unused rooms**: Don't keep rooms attached unnecessarily
2. **Limit history queries**: Use pagination instead of large queries  
3. **Unsubscribe from events**: Cancel subscriptions when not needed
4. **Connection management**: Monitor connection lifecycle

```swift
// Proper cleanup
func leaveRoom() async {
    subscription?.cancel()
    try? await room.detach()
}
```

### Push notifications not working?

**Common issues:**

1. **Certificates**: Verify APNs certificates are valid
2. **Device registration**: Ensure device token registration
3. **Capabilities**: Check `Background App Refresh` and notifications enabled
4. **Sandbox vs Production**: Match certificate environment

### App crashes on background/foreground transitions?

**Background handling:**

```swift
// Handle app state changes
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main
) { _ in
    // Gracefully suspend non-essential operations
    try? await room.detach()
}
```

---

## Performance & Scaling

### How many concurrent users can a room handle?

**Ably scaling capabilities:**

- **Presence members**: 100,000+ per room
- **Message throughput**: 6,500+ messages/second
- **Concurrent connections**: Millions globally
- **Room occupancy**: No practical limit

### What about message history limits?

**Ably message persistence:**

- **Free tier**: 2 million messages, 72 hours retention
- **Paid plans**: Configurable retention (days to years)
- **Message size**: Up to 64KB per message
- **Query pagination**: Handle large histories efficiently

### How do I optimize for large user bases?

**Scaling strategies:**

1. **Room sharding**: Split large audiences across multiple rooms
2. **Selective subscriptions**: Only subscribe to needed events
3. **Lazy loading**: Load message history on demand
4. **Connection pooling**: Share connections across features

```swift
// Efficient room management
class RoomManager {
    private var activeRooms: [String: Room] = [:]
    private let maxActiveRooms = 10
    
    func getRoom(_ id: String) async throws -> Room {
        if let room = activeRooms[id] {
            return room
        }
        
        // Evict least recently used if at capacity
        if activeRooms.count >= maxActiveRooms {
            evictOldestRoom()
        }
        
        let room = try await chatClient.rooms.get(id)
        activeRooms[id] = room
        return room
    }
}
```

### Does it work well on slow networks?

**Network resilience features:**

- ✅ **Automatic reconnection** with exponential backoff
- ✅ **Offline message queuing** for poor connectivity
- ✅ **Delta compression** to minimize bandwidth
- ✅ **Connection fallbacks** (WebSocket → SSE → Polling)

---

## Pricing & Limits

### How much does Ably cost?

**Ably pricing tiers:**

- **Free**: 3 million messages/month, 100 peak connections
- **Starter**: $25/month, 20 million messages, 1,000 peak connections  
- **Pro**: $100/month, 100 million messages, 10,000 peak connections
- **Enterprise**: Custom pricing for large scale

### Are there any hidden costs?

**No hidden costs.** Transparent pricing based on:

- **Message volume**: Per million messages
- **Peak connections**: Concurrent connection count
- **Bandwidth**: Included in message pricing
- **Support**: Available at all tiers

### What counts as a "message"?

**Message counting:**

- ✅ Chat messages sent/received
- ✅ Presence events (enter, leave, update)
- ✅ Typing indicators
- ✅ Message reactions
- ✅ Room reactions
- ❌ Connection events (free)
- ❌ Occupancy updates (free)

### Can I estimate my usage?

**Usage calculation tools:**

1. **Ably usage calculator**: Online planning tool
2. **Dashboard analytics**: Real-time usage monitoring
3. **API usage endpoints**: Programmatic usage queries
4. **Webhooks**: Real-time usage notifications

### What happens if I exceed limits?

**Graceful limit handling:**

- **Soft limits**: Performance may degrade gracefully
- **Notifications**: Email alerts before hard limits
- **Overages**: Automatic billing for usage-based plans
- **Enterprise**: Custom limit arrangements

---

## Migration from Other SDKs

### How do I migrate from Firebase Realtime Database?

**Migration strategy:**

1. **Data structure**: Map Firebase paths to Ably rooms
2. **Authentication**: Replace Firebase Auth with Ably tokens
3. **Real-time listeners**: Convert `.observe()` to `.subscribe()`
4. **Offline support**: Leverage Ably's built-in offline handling

**Code comparison:**

```swift
// Firebase
ref.child("messages").observe(.childAdded) { snapshot in
    // Handle new message
}

// Ably Chat
for await messageEvent in room.messages.subscribe() {
    if messageEvent.type == .created {
        // Handle new message
    }
}
```

### Migrating from Stream Chat SDK?

**Feature mapping:**

| Stream Chat | Ably Chat | Notes |
|-------------|-----------|--------|
| `ChatClient` | `ChatClient` | Similar initialization |
| `Channel` | `Room` | Equivalent concept |
| `Message` | `Message` | Compatible structure |
| `User` | Client ID + Presence | User data in presence |

**Migration steps:**

1. Replace Stream dependencies with Ably Chat
2. Update initialization code
3. Map Stream channels to Ably rooms
4. Convert Stream events to Ably subscriptions
5. Update UI components to use Ably data

### Coming from SendBird?

**Key differences:**

- **Connection management**: Ably handles automatically
- **Message IDs**: Use `serial` instead of `messageId`
- **User sessions**: Managed through Ably presence
- **File uploads**: Implement using your storage service

### What about Socket.io implementations?

**Advantages of migrating:**

- **Reliability**: No more manual reconnection logic
- **Scaling**: Built-in load balancing and failover
- **Features**: Rich chat features out of the box
- **Global**: Multi-region deployment included

**Migration approach:**

1. Identify Socket.io events and map to Ably Chat features
2. Replace custom room management with Ably rooms
3. Convert manual presence tracking to Ably presence
4. Leverage built-in message history vs custom storage

---

## Security & Compliance

### Is the SDK secure for production use?

**Enterprise-grade security:**

- ✅ **SOC 2 Type 2** compliant
- ✅ **HIPAA** eligible
- ✅ **EU GDPR** compliant
- ✅ **TLS 1.2+** encryption in transit
- ✅ **End-to-end encryption** available
- ✅ **Token-based authentication**

### How do I implement access control?

**Permission strategies:**

1. **Token capabilities**: Restrict operations per user
   ```swift
   // Server-side token generation with capabilities
   {
     "keyId": "your-key-id", 
     "clientId": "user123",
     "capability": {
       "room:public-*": ["subscribe", "presence"],
       "room:user-123-*": ["*"]  // Full access to own rooms
     }
   }
   ```

2. **Server-side validation**: Validate operations on your backend
3. **Room-level permissions**: Control who can join specific rooms

### What data is stored by Ably?

**Data storage:**

- **Messages**: Stored according to retention policy
- **Presence data**: Transient (not persisted)
- **Connection logs**: For debugging and analytics
- **User data**: Only what you explicitly send

**Data residency**: Choose your preferred region (US, EU, AP, etc.)

### How do I handle GDPR compliance?

**GDPR tools:**

1. **Data deletion**: Remove user messages and data
2. **Data export**: Extract user's chat history
3. **Consent management**: Control data processing
4. **Regional data**: Process data in specific regions

```swift
// Example: Delete user's messages
let userMessages = try await room.messages.history(
    options: QueryOptions(
        where: ["clientId": "user-to-delete"]
    )
)

for message in userMessages.items {
    try await room.messages.delete(message: message)
}
```

---

## Advanced Usage

### Can I customize connection parameters?

**Advanced connection options:**

```swift
let options = ARTClientOptions(key: "your-key")

// Custom connection settings
options.disconnectedRetryTimeout = 15.0
options.suspendedRetryTimeout = 30.0
options.httpMaxRetryCount = 3
options.realtimeRequestTimeout = 10.0

// Environment and logging
options.environment = "sandbox"  // For testing
options.logLevel = .verbose      // For debugging
```

### How do I implement custom message types?

**Rich message metadata:**

```swift
// Send custom message types
try await room.messages.send(
    params: SendMessageParams(
        text: "", // Can be empty for non-text messages
        metadata: [
            "type": "poll",
            "question": "What's your favorite feature?",
            "options": ["Reactions", "Presence", "Typing"],
            "createdBy": currentUser.id,
            "expiresAt": Date().addingTimeInterval(86400).timeIntervalSince1970
        ]
    )
)

// Handle custom messages
for await messageEvent in room.messages.subscribe() {
    if let messageType = messageEvent.message.metadata?["type"] as? String {
        switch messageType {
        case "poll":
            handlePollMessage(messageEvent.message)
        case "system":
            handleSystemMessage(messageEvent.message)
        default:
            handleTextMessage(messageEvent.message)
        }
    }
}
```

### How do I implement message search?

**Search strategies:**

1. **Client-side search**: Filter loaded messages
2. **Server-side indexing**: Use your search service
3. **Metadata queries**: Search using message metadata

```swift
// Local search in loaded messages
func searchMessages(_ query: String, in messages: [Message]) -> [Message] {
    return messages.filter { message in
        message.text.localizedCaseInsensitiveContains(query)
    }
}

// Server-side search with metadata
let searchResults = try await room.messages.history(
    options: QueryOptions(
        where: ["metadata.tags": ["contains", query.lowercased()]],
        limit: 50
    )
)
```

### Can I build a multi-tenant application?

**Multi-tenancy patterns:**

1. **Namespace isolation**: Use tenant-specific room prefixes
2. **Separate apps**: Different Ably apps per tenant
3. **Token capabilities**: Restrict access per tenant

```swift
// Tenant-specific room naming
let roomId = "\(tenantId):room:\(roomName)"
let room = try await chatClient.rooms.get(roomId)

// Capability-based isolation
let capability = [
    "\(tenantId):*": ["*"]  // Full access to tenant's rooms only
]
```

### How do I implement chat analytics?

**Analytics integration:**

```swift
// Track message events
for await messageEvent in room.messages.subscribe() {
    analytics.track("chat_message_received", properties: [
        "room_id": room.roomId,
        "message_type": messageEvent.message.metadata?["type"] ?? "text",
        "user_id": messageEvent.message.clientId,
        "timestamp": messageEvent.message.timestamp.timeIntervalSince1970
    ])
}

// Track presence events  
for await presenceEvent in room.presence.subscribe() {
    analytics.track("user_presence_changed", properties: [
        "room_id": room.roomId,
        "user_id": presenceEvent.member.clientID,
        "action": presenceEvent.type.rawValue
    ])
}
```

---

## Need More Help?

### Where can I get support?

**Support channels:**

- 📖 **[Documentation](https://ably.com/docs/chat/setup?lang=swift)** - Complete guides and tutorials
- 💬 **[Community Forum](https://community.ably.com/)** - Ask questions and share experiences  
- 🐛 **[GitHub Issues](https://github.com/ably/ably-chat-swift/issues)** - Report bugs and feature requests
- 📧 **[Support Portal](https://ably.com/support)** - Direct technical support
- 💡 **[Examples](https://github.com/ably/ably-chat-swift/tree/main/examples)** - Code samples and demos

### How do I stay updated?

- ⭐ **Star the repository** for updates
- 📱 **Follow [@ablyrealtime](https://twitter.com/ablyrealtime)** on Twitter
- 📰 **Subscribe to [Ably changelog](https://changelog.ably.com)**
- 📧 **Join the developer newsletter**

### Can I contribute to the SDK?

**Yes! Contributions welcome:**

1. **Report issues** - Found a bug? Let us know!
2. **Suggest features** - Ideas for improvements
3. **Submit PRs** - Code contributions following our guidelines
4. **Documentation** - Help improve docs and examples
5. **Community support** - Help other developers in forums

See our [Contributing Guide](https://github.com/ably/ably-chat-swift/blob/main/CONTRIBUTING.md) for details.

---

*This FAQ is regularly updated. For the latest information, visit the [official documentation](https://ably.com/docs/chat/setup?lang=swift).*