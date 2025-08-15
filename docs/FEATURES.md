# Ably Chat Swift SDK - Complete Feature Reference

This comprehensive guide documents all features available in the **Ably Chat Swift SDK**, the premier **iOS chat SDK** for building **realtime messaging** applications on Apple platforms.

## Table of Contents

- [Real-time Messaging](#-real-time-messaging)
- [User Presence System](#-user-presence-system)  
- [Typing Indicators](#-typing-indicators)
- [Message Reactions](#-message-reactions)
- [Room-Level Reactions](#-room-level-reactions)
- [Room Occupancy Metrics](#-room-occupancy-metrics)
- [Connection Management](#-connection-management)
- [Room Lifecycle Management](#-room-lifecycle-management)
- [Push Notifications](#-push-notifications)

---

## 📨 Real-time Messaging

**Keywords**: realtime messaging, chat messages, message history, message operations, Swift messaging

The core messaging feature provides complete **realtime message synchronization** across all connected clients with full CRUD operations.

### Key Capabilities

- ✅ **Send, update, and delete messages** with real-time delivery
- ✅ **Message history** with pagination and filtering
- ✅ **Rich message metadata** and custom headers  
- ✅ **Message threading** and conversation support
- ✅ **Delivery guarantees** and offline queuing
- ✅ **Message reactions** integration

### Basic Message Operations

```swift
import AblyChat

// Send a message
let message = try await room.messages.send(
    params: SendMessageParams(
        text: "Hello everyone! 👋",
        metadata: [
            "messageType": "greeting",
            "priority": "normal",
            "formatting": ["bold": false]
        ],
        headers: [
            "x-custom-id": "msg-12345",
            "x-source": "mobile-app"
        ]
    )
)

print("Message sent: \(message.id)")
```

### Message Subscriptions

```swift
// Subscribe to all message events (recommended approach)
for await messageEvent in room.messages.subscribe() {
    switch messageEvent.type {
    case .created:
        print("📨 New message from \(messageEvent.message.clientId)")
        print("Content: \(messageEvent.message.text)")
        updateUI(with: messageEvent.message)
        
    case .updated:
        print("✏️ Message updated: \(messageEvent.message.id)")
        refreshMessage(messageEvent.message)
        
    case .deleted:
        print("🗑️ Message deleted: \(messageEvent.message.id)")
        removeMessageFromUI(messageEvent.message.id)
    }
}

// Alternative: Callback-based subscription
let subscription = room.messages.subscribe { messageEvent in
    // Handle message events
}
```

### Message History & Pagination

```swift
// Query recent messages
let recentMessages = try await room.messages.history(
    options: QueryOptions(
        limit: 50,
        orderBy: .newestFirst
    )
)

// Display messages
for message in recentMessages.items {
    print("\(message.clientId): \(message.text)")
}

// Load older messages
if let next = recentMessages.next {
    let olderMessages = try await next()
    print("Loaded \(olderMessages.items.count) older messages")
}

// Query messages from specific time range
let yesterdayMessages = try await room.messages.history(
    options: QueryOptions(
        start: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        end: Date(),
        limit: 100,
        orderBy: .oldestFirst
    )
)
```

### Advanced Message Operations

```swift
// Update an existing message
let updatedMessage = message.copy(
    text: "Hello everyone! 👋 (edited)",
    metadata: ["edited": true, "editTimestamp": Date().timeIntervalSince1970]
)

let result = try await room.messages.update(
    newMessage: updatedMessage,
    description: "Fixed typo in greeting",
    metadata: ["editReason": "typo_correction"]
)

// Delete a message
try await room.messages.delete(
    message: message,
    params: DeleteMessageParams(
        description: "Message removed by moderator",
        metadata: ["moderation": ["reason": "spam", "moderatorId": "admin123"]]
    )
)
```

### Use Cases

- **In-app messaging**: User-to-user communication in social apps
- **Customer support**: Real-time support conversations  
- **Team collaboration**: Slack-like messaging experiences
- **Live chat**: Website or app live chat widgets
- **Gaming chat**: In-game communication systems

---

## 👥 User Presence System

**Keywords**: user presence, online status, presence events, user awareness, activity indicators

The **presence system** provides real-time **user awareness** showing who's online, offline, or away in each chat room.

### Key Capabilities

- ✅ **Real-time presence updates** (enter, leave, update)
- ✅ **Custom presence data** for user profiles and status
- ✅ **Presence member listing** with filtering options
- ✅ **Automatic presence management** with connection state
- ✅ **Presence synchronization** across all clients

### Basic Presence Operations

```swift
// Enter presence with custom data
try await room.presence.enter(data: [
    "status": "active",
    "avatar": "https://example.com/avatars/user123.jpg",
    "displayName": "John Doe",
    "location": "San Francisco",
    "mood": "😄"
])

// Update presence data
try await room.presence.update(data: [
    "status": "away",
    "lastActivity": Date().timeIntervalSince1970,
    "statusMessage": "In a meeting"
])

// Leave presence
try await room.presence.leave(data: [
    "leftAt": Date().timeIntervalSince1970,
    "reason": "session_ended"
])
```

### Presence Event Subscriptions

```swift
// Subscribe to all presence events
for await presenceEvent in room.presence.subscribe(events: [.enter, .leave, .update]) {
    switch presenceEvent.type {
    case .enter:
        print("🟢 \(presenceEvent.member.clientID) joined the room")
        addUserToOnlineList(presenceEvent.member)
        
    case .leave:
        print("🔴 \(presenceEvent.member.clientID) left the room")
        removeUserFromOnlineList(presenceEvent.member.clientID)
        
    case .update:
        print("🟡 \(presenceEvent.member.clientID) updated their status")
        updateUserStatus(presenceEvent.member)
        
    case .present:
        print("👤 \(presenceEvent.member.clientID) was already present")
        addUserToOnlineList(presenceEvent.member)
    }
}

// Subscribe to specific events only
for await presenceEvent in room.presence.subscribe(event: .enter) {
    print("New user joined: \(presenceEvent.member.clientID)")
}
```

### Presence Member Management

```swift
// Get all current presence members
let allMembers = try await room.presence.get()
print("Currently \(allMembers.count) users online")

for member in allMembers {
    if let userData = member.data {
        print("User: \(member.clientID), Status: \(userData)")
    }
}

// Get presence with filtering
let specificUser = try await room.presence.get(
    params: PresenceParams(
        clientID: "user123",
        waitForSync: true
    )
)

// Check if specific user is present
let isOnline = try await room.presence.isUserPresent(clientID: "user456")
if isOnline {
    print("User456 is currently online")
}
```

### Use Cases

- **Social apps**: Show online friends and their status
- **Customer support**: Display agent availability  
- **Gaming**: Show active players in lobbies
- **Team tools**: Team member availability indicators
- **Live events**: Audience presence for livestreams

---

## ⚡ Typing Indicators

**Keywords**: typing indicators, typing events, keystroke detection, typing awareness, real-time typing

**Typing indicators** show real-time **typing awareness** when users are composing messages, enhancing the conversational experience.

### Key Capabilities

- ✅ **Real-time typing notifications** with automatic timeouts
- ✅ **Multi-user typing support** showing all typing users
- ✅ **Configurable typing timeouts** and heartbeat management  
- ✅ **Automatic cleanup** when users stop typing
- ✅ **Efficient batching** for performance optimization

### Basic Typing Operations

```swift
// Start typing (call on keystroke)
try await room.typing.keystroke()

// Stop typing explicitly
try await room.typing.stop()

// Get current typers
let currentTypers = try await room.typing.get()
print("Currently typing: \(currentTypers.joined(separator: ", "))")
```

### Typing Event Subscriptions

```swift
// Subscribe to typing events
for await typingEvent in room.typing.subscribe() {
    let typingUsers = Array(typingEvent.currentlyTyping)
    
    switch typingEvent.change.type {
    case .started:
        print("✍️ \(typingEvent.change.clientId) started typing")
        print("All typing users: \(typingUsers)")
        showTypingIndicator(for: typingUsers)
        
    case .stopped:
        print("⏸️ \(typingEvent.change.clientId) stopped typing")
        updateTypingIndicator(for: typingUsers)
    }
}

// Callback-based subscription
let typingSubscription = room.typing.subscribe { typingEvent in
    updateTypingUI(typingEvent.currentlyTyping)
}
```

### Advanced Typing Management

```swift
// Custom typing timeout configuration
let roomOptions = RoomOptions(
    typing: TypingOptions(
        heartbeatThrottle: TimeInterval(2.0) // 2 second throttle
    )
)

let room = try await chatClient.rooms.get("chat-room", options: roomOptions)

// Handle typing in text field
func textFieldDidChange(_ textField: UITextField) {
    // Only send typing events when user is actively typing
    if !textField.text.isEmpty {
        Task {
            try? await room.typing.keystroke()
        }
    }
}

func textFieldDidEndEditing(_ textField: UITextField) {
    Task {
        try? await room.typing.stop()
    }
}
```

### UI Implementation Examples

```swift
// SwiftUI typing indicator component
struct TypingIndicatorView: View {
    @State private var typingUsers: Set<String> = []
    let room: Room
    
    var body: some View {
        if !typingUsers.isEmpty {
            HStack {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundColor(.secondary)
                    .scaleEffect(1.2)
                
                Text(typingText)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .task {
                for await typingEvent in room.typing.subscribe() {
                    typingUsers = typingEvent.currentlyTyping
                }
            }
        }
    }
    
    private var typingText: String {
        let users = Array(typingUsers)
        switch users.count {
        case 1:
            return "\(users[0]) is typing..."
        case 2:
            return "\(users[0]) and \(users[1]) are typing..."
        default:
            return "\(users.count) people are typing..."
        }
    }
}
```

### Use Cases

- **Messaging apps**: Show typing indicators in conversations
- **Customer support**: Indicate when agents are responding
- **Collaborative editing**: Show active editors
- **Gaming chat**: Real-time typing in game chats
- **Social platforms**: Enhance engagement with typing awareness

---

## 😍 Message Reactions

**Keywords**: message reactions, emoji reactions, reaction events, message annotations, social reactions

**Message reactions** enable users to **react to specific messages** with emojis or custom reactions, adding social interaction to conversations.

### Key Capabilities

- ✅ **Emoji reactions** with Unicode support
- ✅ **Custom reaction types** and names
- ✅ **Reaction aggregation** and counting
- ✅ **Real-time reaction updates** across all clients
- ✅ **Multiple reaction types** (unique, multiple, etc.)

### Basic Reaction Operations

```swift
// Add a reaction to a message
try await room.messages.reactions.send(
    to: message.serial,
    params: SendMessageReactionParams(
        name: "👍",
        type: .unique, // or .multiple for counting reactions
        count: 1
    )
)

// Remove a reaction
try await room.messages.reactions.delete(
    from: message.serial,
    params: DeleteMessageReactionParams(
        name: "👍",
        type: .unique
    )
)
```

### Reaction Event Subscriptions

```swift
// Subscribe to reaction summary events (recommended)
for await reactionEvent in room.messages.reactions.subscribe() {
    print("Reaction update for message: \(reactionEvent.messageId)")
    print("Reaction: \(reactionEvent.type)")
    
    // Update UI with new reaction counts
    updateMessageReactions(
        messageId: reactionEvent.messageId,
        reactions: reactionEvent.reactions
    )
}

// Subscribe to raw reaction events (individual reactions)
for await rawReactionEvent in room.messages.reactions.subscribeRaw() {
    switch rawReactionEvent.type {
    case .added:
        print("➕ Reaction added: \(rawReactionEvent.reaction.name)")
        animateReactionAdded(rawReactionEvent.reaction)
        
    case .removed:
        print("➖ Reaction removed: \(rawReactionEvent.reaction.name)")
        animateReactionRemoved(rawReactionEvent.reaction)
    }
}
```

### Advanced Reaction Features

```swift
// Multiple reaction types
try await room.messages.reactions.send(
    to: message.serial,
    params: SendMessageReactionParams(
        name: "love",
        type: .multiple,
        count: 5 // User can react multiple times
    )
)

// Custom reaction metadata
try await room.messages.reactions.send(
    to: message.serial,
    params: SendMessageReactionParams(
        name: "custom_celebration",
        metadata: [
            "animation": "confetti",
            "color": "#FFD700",
            "duration": 3.0
        ]
    )
)
```

### UI Implementation Examples

```swift
// SwiftUI message reactions view
struct MessageReactionsView: View {
    let message: Message
    let room: Room
    @State private var reactions: [String: Int] = [:]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(reactions.keys.sorted()), id: \.self) { reaction in
                    ReactionButton(
                        emoji: reaction,
                        count: reactions[reaction] ?? 0,
                        onTap: {
                            Task {
                                try await toggleReaction(reaction)
                            }
                        }
                    )
                }
                
                AddReactionButton {
                    // Show reaction picker
                }
            }
            .padding(.horizontal)
        }
        .task {
            // Subscribe to reaction updates for this message
            for await reactionEvent in room.messages.reactions.subscribe() {
                if reactionEvent.messageId == message.id {
                    updateReactions(reactionEvent.reactions)
                }
            }
        }
    }
    
    private func toggleReaction(_ emoji: String) async throws {
        if reactions[emoji] ?? 0 > 0 {
            // Remove reaction
            try await room.messages.reactions.delete(
                from: message.serial,
                params: DeleteMessageReactionParams(name: emoji)
            )
        } else {
            // Add reaction
            try await room.messages.reactions.send(
                to: message.serial,
                params: SendMessageReactionParams(name: emoji)
            )
        }
    }
}
```

### Use Cases

- **Social messaging**: Express emotions without typing
- **Team collaboration**: Quick feedback on messages
- **Customer feedback**: Rate support interactions
- **Community forums**: Upvote/downvote system
- **Live events**: Audience reactions to content

---

## 🎭 Room-Level Reactions

**Keywords**: room reactions, live reactions, broadcast reactions, audience engagement, livestream reactions

**Room-level reactions** enable **live audience engagement** perfect for livestreams, events, and broadcast scenarios where reactions are shared across the entire room.

### Key Capabilities

- ✅ **Live audience reactions** for events and streams  
- ✅ **Real-time broadcast** to all room participants
- ✅ **Custom reaction effects** with metadata
- ✅ **High-throughput reaction handling** for large audiences
- ✅ **Rich reaction metadata** for animations and effects

### Basic Room Reactions

```swift
// Send a room-level reaction
try await room.reactions.send(
    params: SendReactionParams(
        name: "❤️",
        metadata: [
            "animation": "hearts",
            "intensity": "high",
            "color": "#FF69B4"
        ],
        headers: [
            "x-reaction-source": "mobile",
            "x-user-tier": "premium"
        ]
    )
)

// Send custom reactions for special events
try await room.reactions.send(
    params: SendReactionParams(
        name: "celebration",
        metadata: [
            "effect": "confetti",
            "duration": 5.0,
            "colors": ["#FFD700", "#FF6B6B", "#4ECDC4"]
        ]
    )
)
```

### Room Reaction Subscriptions

```swift
// Subscribe to room-level reactions
for await reactionEvent in room.reactions.subscribe() {
    let reaction = reactionEvent.reaction
    
    print("🎉 Room reaction: \(reaction.name)")
    print("From: \(reaction.clientId)")
    print("Timestamp: \(reaction.timestamp)")
    
    // Trigger animation based on reaction type
    if reaction.name == "❤️" {
        showHeartAnimation()
    } else if reaction.name == "celebration" {
        showConfettiEffect(reaction.metadata)
    }
    
    // Display floating reaction
    showFloatingReaction(
        emoji: reaction.name,
        from: reaction.clientId,
        metadata: reaction.metadata
    )
}
```

### Advanced Room Reaction Features

```swift
// Batch reactions for high-engagement scenarios
class LivestreamReactionManager {
    private let room: Room
    private var reactionQueue: [String] = []
    private var isProcessing = false
    
    func queueReaction(_ emoji: String) {
        reactionQueue.append(emoji)
        processQueueIfNeeded()
    }
    
    private func processQueueIfNeeded() {
        guard !isProcessing && !reactionQueue.isEmpty else { return }
        
        isProcessing = true
        Task {
            while !reactionQueue.isEmpty {
                let reaction = reactionQueue.removeFirst()
                try? await room.reactions.send(
                    params: SendReactionParams(name: reaction)
                )
                // Small delay to prevent overwhelming
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            isProcessing = false
        }
    }
}
```

### UI Implementation for Live Events

```swift
// SwiftUI livestream reaction overlay
struct LiveReactionOverlay: View {
    let room: Room
    @State private var activeReactions: [ReactionAnimation] = []
    
    var body: some View {
        ZStack {
            ForEach(activeReactions) { reaction in
                ReactionAnimationView(reaction: reaction)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            for await reactionEvent in room.reactions.subscribe() {
                withAnimation(.easeOut(duration: 2.0)) {
                    let animation = ReactionAnimation(
                        id: UUID(),
                        emoji: reactionEvent.reaction.name,
                        startPosition: randomStartPosition(),
                        metadata: reactionEvent.reaction.metadata
                    )
                    activeReactions.append(animation)
                    
                    // Remove after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        activeReactions.removeAll { $0.id == animation.id }
                    }
                }
            }
        }
    }
    
    private func randomStartPosition() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 50...300),
            y: UIScreen.main.bounds.height
        )
    }
}

// Quick reaction picker for mobile
struct QuickReactionPicker: View {
    let room: Room
    let reactions = ["❤️", "👍", "😂", "🔥", "👏", "🎉"]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(reactions, id: \.self) { emoji in
                Button(action: {
                    Task {
                        try? await room.reactions.send(
                            params: SendReactionParams(name: emoji)
                        )
                    }
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    Text(emoji)
                        .font(.title2)
                        .scaleEffect(1.2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(25)
    }
}
```

### Use Cases

- **Livestreaming**: Audience reactions during live broadcasts
- **Virtual events**: Conference and webinar engagement
- **Gaming streams**: Viewer reactions to gameplay
- **Social media**: Live video reactions
- **Entertainment**: Concert and performance engagement

---

## 📊 Room Occupancy Metrics

**Keywords**: occupancy metrics, room capacity, user counting, connection metrics, audience size

**Room occupancy** provides **real-time audience metrics** showing connection counts and presence member statistics for monitoring engagement.

### Key Capabilities

- ✅ **Real-time connection counting** for active users
- ✅ **Presence member metrics** for engaged users  
- ✅ **Occupancy event updates** when metrics change
- ✅ **Scalable counting** for large audiences
- ✅ **Historical occupancy data** for analytics

### Basic Occupancy Operations

```swift
// Get current occupancy metrics
let occupancy = try await room.occupancy.get()
print("Active connections: \(occupancy.connections)")
print("Presence members: \(occupancy.presenceMembers)")
print("Total audience: \(occupancy.connections)")

// Display engagement metrics
updateAudienceCounter(occupancy.connections)
updateEngagementLevel(occupancy.presenceMembers)
```

### Occupancy Event Subscriptions

```swift
// Subscribe to occupancy updates
for await occupancyEvent in room.occupancy.subscribe() {
    let data = occupancyEvent.occupancy
    
    switch occupancyEvent.type {
    case .updated:
        print("📈 Occupancy updated:")
        print("  Connections: \(data.connections)")
        print("  Engaged users: \(data.presenceMembers)")
        
        // Update UI with new metrics
        updateOccupancyDisplay(data)
        
        // Trigger engagement notifications
        if data.connections > 1000 {
            showHighEngagementAlert()
        }
    }
}
```

### Advanced Occupancy Features

```swift
// Configure occupancy tracking
let roomOptions = RoomOptions(
    occupancy: OccupancyOptions(
        enableEvents: true
    )
)

let room = try await chatClient.rooms.get("livestream-room", options: roomOptions)

// Occupancy analytics manager
class OccupancyAnalytics {
    private var maxOccupancy = 0
    private var occupancyHistory: [(Date, Int)] = []
    
    func trackOccupancy(_ occupancy: OccupancyData) {
        // Track peak occupancy
        maxOccupancy = max(maxOccupancy, occupancy.connections)
        
        // Record occupancy data point
        occupancyHistory.append((Date(), occupancy.connections))
        
        // Cleanup old data (keep last 24 hours)
        let cutoff = Date().addingTimeInterval(-86400)
        occupancyHistory.removeAll { $0.0 < cutoff }
        
        // Generate insights
        if occupancy.connections > maxOccupancy * 0.9 {
            triggerHighEngagementEvent()
        }
    }
    
    func getEngagementRate() -> Double {
        guard !occupancyHistory.isEmpty else { return 0.0 }
        
        let totalConnections = occupancyHistory.reduce(0) { $0 + $1.1 }
        return Double(totalConnections) / Double(occupancyHistory.count)
    }
}
```

### UI Implementation Examples

```swift
// SwiftUI occupancy dashboard
struct OccupancyDashboard: View {
    let room: Room
    @State private var occupancy = OccupancyData(connections: 0, presenceMembers: 0)
    @State private var isLive = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Live indicator
            HStack {
                Circle()
                    .fill(isLive ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isLive ? "LIVE" : "OFFLINE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            // Occupancy metrics
            HStack(spacing: 24) {
                MetricView(
                    title: "Viewers",
                    value: "\(occupancy.connections)",
                    icon: "eye.fill"
                )
                
                MetricView(
                    title: "Engaged",
                    value: "\(occupancy.presenceMembers)",
                    icon: "person.fill"
                )
            }
            
            // Engagement rate
            let engagementRate = occupancy.connections > 0 
                ? Double(occupancy.presenceMembers) / Double(occupancy.connections)
                : 0.0
            
            ProgressView(value: engagementRate) {
                Text("Engagement: \(Int(engagementRate * 100))%")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .task {
            // Initial load
            do {
                occupancy = try await room.occupancy.get()
                isLive = occupancy.connections > 0
            } catch {
                print("Failed to load initial occupancy: \(error)")
            }
            
            // Subscribe to updates
            for await occupancyEvent in room.occupancy.subscribe() {
                occupancy = occupancyEvent.occupancy
                isLive = occupancy.connections > 0
            }
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### Use Cases

- **Livestreaming**: Monitor audience size and engagement
- **Virtual events**: Track attendee participation
- **Gaming**: Monitor active players in lobbies
- **Social platforms**: Measure room popularity
- **Analytics**: Audience engagement insights

---

## 🔗 Connection Management

**Keywords**: connection management, network resilience, connection status, offline support, automatic reconnection

**Connection management** provides robust **network resilience** with automatic reconnection, offline support, and connection state monitoring.

### Key Capabilities

- ✅ **Automatic reconnection** with exponential backoff
- ✅ **Connection state monitoring** and events
- ✅ **Offline message queuing** and delivery
- ✅ **Network resilience** across different connection types
- ✅ **Connection quality indicators** for UI feedback

### Connection Status Monitoring

```swift
// Monitor connection status
for await connectionStateChange in chatClient.connection.onStatusChange() {
    switch connectionStateChange.current {
    case .connected:
        print("🟢 Connected to Ably")
        showConnectionStatus(.connected)
        flushOfflineQueue()
        
    case .connecting:
        print("🟡 Connecting...")
        showConnectionStatus(.connecting)
        
    case .disconnected:
        print("🔴 Disconnected")
        showConnectionStatus(.disconnected)
        enableOfflineMode()
        
    case .suspended:
        print("⏸️ Connection suspended")
        showConnectionStatus(.suspended)
        
    case .failed(let error):
        print("❌ Connection failed: \(error.localizedDescription)")
        showConnectionStatus(.failed(error))
        handleConnectionFailure(error)
    }
}

// Check current connection status
let currentStatus = chatClient.connection.status
print("Current connection: \(currentStatus)")
```

### Advanced Connection Features

```swift
// Connection manager for robust handling
class ChatConnectionManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isOfflineMode = false
    
    private let chatClient: ChatClient
    private var offlineMessageQueue: [PendingMessage] = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
        monitorConnection()
    }
    
    private func monitorConnection() {
        Task {
            for await statusChange in chatClient.connection.onStatusChange() {
                await MainActor.run {
                    connectionStatus = statusChange.current
                    handleConnectionChange(statusChange.current)
                }
            }
        }
    }
    
    private func handleConnectionChange(_ status: ConnectionStatus) {
        switch status {
        case .connected:
            isOfflineMode = false
            reconnectAttempts = 0
            processOfflineQueue()
            
        case .disconnected, .suspended:
            isOfflineMode = true
            
        case .failed(let error):
            handleConnectionFailure(error)
            
        case .connecting:
            break // UI already shows connecting state
        }
    }
    
    private func processOfflineQueue() {
        guard !offlineMessageQueue.isEmpty else { return }
        
        Task {
            for pendingMessage in offlineMessageQueue {
                do {
                    try await sendMessage(pendingMessage)
                } catch {
                    print("Failed to send queued message: \(error)")
                }
            }
            offlineMessageQueue.removeAll()
        }
    }
    
    func sendMessageWithOfflineSupport(_ message: PendingMessage) {
        if connectionStatus == .connected {
            Task {
                try await sendMessage(message)
            }
        } else {
            // Queue for later delivery
            offlineMessageQueue.append(message)
            showOfflineQueuedMessage()
        }
    }
}

struct PendingMessage {
    let roomId: String
    let text: String
    let metadata: MessageMetadata?
    let timestamp: Date
}
```

### UI Implementation for Connection Status

```swift
// SwiftUI connection status indicator
struct ConnectionStatusView: View {
    @ObservedObject var connectionManager: ChatConnectionManager
    
    var body: some View {
        HStack(spacing: 8) {
            connectionIndicator
            connectionText
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(connectionColor.opacity(0.1))
        .foregroundColor(connectionColor)
        .cornerRadius(16)
        .font(.caption)
    }
    
    private var connectionIndicator: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 8, height: 8)
            .scaleEffect(connectionManager.connectionStatus == .connecting ? 1.2 : 1.0)
            .animation(.pulse.repeatForever(), value: connectionManager.connectionStatus)
    }
    
    private var connectionText: String {
        if connectionManager.isOfflineMode {
            return "Offline (\(connectionManager.queuedMessageCount) queued)"
        }
        
        switch connectionManager.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .suspended:
            return "Connection suspended"
        case .failed:
            return "Connection failed"
        }
    }
    
    private var connectionColor: Color {
        switch connectionManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .suspended, .failed:
            return .red
        }
    }
}
```

### Use Cases

- **Mobile apps**: Handle network switching and poor connectivity
- **Real-time apps**: Maintain seamless user experience
- **Offline-first**: Queue operations when disconnected
- **Live events**: Handle high-traffic connection stability
- **Enterprise**: Monitor connection health for SLA compliance

---

## 🏠 Room Lifecycle Management

**Keywords**: room lifecycle, room status, attach detach, room management, connection states

**Room lifecycle management** handles **room attachment states** and provides comprehensive **room status monitoring** for reliable real-time communication.

### Key Capabilities

- ✅ **Room status tracking** (attached, detached, suspended, failed)
- ✅ **Automatic attachment management** with error handling
- ✅ **Room lifecycle events** and state transitions
- ✅ **Graceful error recovery** and retry mechanisms
- ✅ **Multi-room coordination** for complex apps

### Basic Room Lifecycle

```swift
// Get room and monitor status
let room = try await chatClient.rooms.get("main-chat", options: roomOptions)

// Attach to room for real-time events
try await room.attach()
print("Room attached successfully")

// Monitor room status changes
for await statusChange in room.onStatusChange() {
    switch statusChange.current {
    case .attached:
        print("✅ Room ready for real-time events")
        enableRealTimeFeatures()
        
    case .detached:
        print("⏸️ Room disconnected")
        disableRealTimeFeatures()
        
    case .suspended(let error):
        print("⚠️ Room suspended: \(error.localizedDescription)")
        handleRoomSuspension(error)
        
    case .failed(let error):
        print("❌ Room failed: \(error.localizedDescription)")
        handleRoomFailure(error)
        
    case .attaching:
        print("🔄 Attaching to room...")
        showLoadingState()
        
    case .detaching:
        print("🔄 Detaching from room...")
        showLoadingState()
    }
}

// Detach when done
try await room.detach()
```

### Advanced Room Management

```swift
// Room manager for multiple rooms
class MultiRoomManager: ObservableObject {
    @Published var activeRooms: [String: RoomState] = [:]
    
    private let chatClient: ChatClient
    private var roomSubscriptions: [String: AnyCancellable] = [:]
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
    }
    
    func joinRoom(_ roomId: String, options: RoomOptions? = nil) async throws {
        let room = try await chatClient.rooms.get(roomId, options: options ?? RoomOptions())
        
        // Monitor room status
        let subscription = room.onStatusChange()
            .sink { [weak self] statusChange in
                self?.updateRoomState(roomId, status: statusChange.current)
            }
        
        roomSubscriptions[roomId] = subscription
        activeRooms[roomId] = RoomState(room: room, status: .attaching)
        
        do {
            try await room.attach()
        } catch {
            activeRooms[roomId]?.status = .failed(error as! ARTErrorInfo)
            throw error
        }
    }
    
    func leaveRoom(_ roomId: String) async {
        guard let roomState = activeRooms[roomId] else { return }
        
        do {
            try await roomState.room.detach()
        } catch {
            print("Error detaching from room: \(error)")
        }
        
        roomSubscriptions[roomId]?.cancel()
        roomSubscriptions.removeValue(forKey: roomId)
        activeRooms.removeValue(forKey: roomId)
    }
    
    private func updateRoomState(_ roomId: String, status: RoomStatus) {
        activeRooms[roomId]?.status = status
        
        // Handle room-specific logic
        switch status {
        case .suspended(let error):
            // Attempt automatic recovery
            Task {
                try? await recoverRoom(roomId, error: error)
            }
            
        case .failed(let error):
            // Notify user and require manual intervention
            handleRoomFailure(roomId, error: error)
            
        default:
            break
        }
    }
    
    private func recoverRoom(_ roomId: String, error: ARTErrorInfo) async throws {
        guard let roomState = activeRooms[roomId] else { return }
        
        // Wait before retry
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Attempt to reattach
        try await roomState.room.attach()
    }
}

struct RoomState {
    let room: Room
    var status: RoomStatus
}
```

### Room Status UI Implementation

```swift
// SwiftUI room status indicator
struct RoomStatusIndicator: View {
    let roomId: String
    @State private var roomStatus: RoomStatus = .detached
    let room: Room
    
    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
        .task {
            for await statusChange in room.onStatusChange() {
                roomStatus = statusChange.current
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch roomStatus {
            case .attached:
                Image(systemName: "checkmark.circle.fill")
            case .attaching, .detaching:
                ProgressView()
                    .scaleEffect(0.8)
            case .detached:
                Image(systemName: "circle")
            case .suspended:
                Image(systemName: "pause.circle.fill")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .font(.caption)
    }
    
    private var statusText: String {
        switch roomStatus {
        case .attached:
            return "Connected"
        case .attaching:
            return "Connecting..."
        case .detaching:
            return "Disconnecting..."
        case .detached:
            return "Disconnected"
        case .suspended:
            return "Suspended"
        case .failed:
            return "Failed"
        }
    }
    
    private var statusColor: Color {
        switch roomStatus {
        case .attached:
            return .green
        case .attaching, .detaching:
            return .orange
        case .detached:
            return .gray
        case .suspended:
            return .yellow
        case .failed:
            return .red
        }
    }
}
```

### Error Recovery Patterns

```swift
// Robust room attachment with retry logic
extension Room {
    func attachWithRetry(maxAttempts: Int = 3, delay: TimeInterval = 1.0) async throws {
        var attempts = 0
        var lastError: ARTErrorInfo?
        
        while attempts < maxAttempts {
            do {
                try await attach()
                return // Success
            } catch {
                lastError = error as? ARTErrorInfo
                attempts += 1
                
                if attempts < maxAttempts {
                    print("Attach attempt \(attempts) failed, retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2 // Exponential backoff
                }
            }
        }
        
        // All attempts failed
        throw lastError ?? ARTErrorInfo(domain: "ChatRoom", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Failed to attach after \(maxAttempts) attempts"
        ])
    }
}
```

### Use Cases

- **Chat apps**: Manage connection state per conversation
- **Live events**: Handle room lifecycle during broadcasts  
- **Gaming**: Manage lobby and game room states
- **Collaboration**: Track room connectivity in team apps
- **Multi-room**: Coordinate multiple simultaneous chat rooms

---

## 🔔 Push Notifications

**Keywords**: push notifications, iOS notifications, remote notifications, notification integration, mobile notifications

**Push notifications** provide native **iOS notification support** to keep users engaged with **message notifications**, **mention alerts**, and **activity updates**.

### Key Capabilities

- ✅ **Native iOS push integration** with rich notifications
- ✅ **Message-based notifications** with preview content
- ✅ **Presence and activity notifications** 
- ✅ **Custom notification payloads** and actions
- ✅ **Notification categories** and user preferences

### Basic Push Notification Setup

```swift
import UserNotifications
import AblyChat

// Configure push notifications
class ChatNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    let chatClient: ChatClient
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
        super.init()
        setupNotifications()
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        
        // Configure notification categories
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [.foreground],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your message..."
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE_CATEGORY",
            actions: [replyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([messageCategory])
    }
}
```

### Advanced Notification Features

```swift
// Handle notification interactions
extension ChatNotificationManager {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is active
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                handleQuickReply(
                    text: textResponse.userText,
                    notification: userInfo
                )
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            navigateToChat(from: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleQuickReply(text: String, notification: [AnyHashable: Any]) {
        guard let roomId = notification["roomId"] as? String else { return }
        
        Task {
            do {
                let room = try await chatClient.rooms.get(roomId)
                try await room.messages.send(params: SendMessageParams(text: text))
            } catch {
                print("Failed to send quick reply: \(error)")
            }
        }
    }
    
    private func navigateToChat(from userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["roomId"] as? String else { return }
        
        // Navigate to specific chat room
        NotificationCenter.default.post(
            name: .navigateToChat,
            object: nil,
            userInfo: ["roomId": roomId]
        )
    }
}

extension Notification.Name {
    static let navigateToChat = Notification.Name("navigateToChat")
}
```

### Smart Notification Logic

```swift
// Intelligent notification manager
class SmartNotificationManager {
    private let chatClient: ChatClient
    private var notificationPreferences: NotificationPreferences = .default
    
    func setupMessageNotifications(for room: Room) {
        Task {
            for await messageEvent in room.messages.subscribe() {
                await handleMessageForNotification(messageEvent, in: room)
            }
        }
    }
    
    private func handleMessageForNotification(_ event: ChatMessageEvent, in room: Room) async {
        // Don't notify for own messages
        guard event.message.clientId != chatClient.clientID else { return }
        
        // Check if app is in background
        guard UIApplication.shared.applicationState != .active else { return }
        
        // Check notification preferences
        guard shouldNotify(for: event, in: room) else { return }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = getRoomDisplayName(room)
        content.body = formatMessageForNotification(event.message)
        content.sound = .default
        content.badge = await getUnreadBadgeCount()
        content.categoryIdentifier = "MESSAGE_CATEGORY"
        
        // Add custom data
        content.userInfo = [
            "roomId": room.name,
            "messageId": event.message.id,
            "senderId": event.message.clientId
        ]
        
        // Schedule notification
        let request = UNNotificationRequest(
            identifier: "message-\(event.message.id)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    private func shouldNotify(for event: ChatMessageEvent, in room: Room) -> Bool {
        // Don't notify if user is mentioned but has mentions disabled
        if event.message.text.contains("@\(chatClient.clientID)") {
            return notificationPreferences.mentionsEnabled
        }
        
        // Check DND settings
        if notificationPreferences.isDoNotDisturbActive {
            return false
        }
        
        // Check room-specific settings
        return notificationPreferences.isEnabledForRoom(room.name)
    }
    
    private func getUnreadBadgeCount() async -> Int {
        // Calculate total unread messages across all rooms
        // Implementation depends on your unread tracking system
        return 0
    }
}

struct NotificationPreferences {
    var mentionsEnabled = true
    var allMessagesEnabled = true
    var isDoNotDisturbActive = false
    var enabledRooms: Set<String> = []
    
    static let `default` = NotificationPreferences()
    
    func isEnabledForRoom(_ roomId: String) -> Bool {
        allMessagesEnabled || enabledRooms.contains(roomId)
    }
}
```

### Notification Settings UI

```swift
// SwiftUI notification preferences
struct NotificationSettingsView: View {
    @State private var preferences = NotificationPreferences.default
    
    var body: some View {
        Form {
            Section("Message Notifications") {
                Toggle("All Messages", isOn: $preferences.allMessagesEnabled)
                Toggle("Mentions Only", isOn: $preferences.mentionsEnabled)
                    .disabled(preferences.allMessagesEnabled)
            }
            
            Section("Do Not Disturb") {
                Toggle("Enable DND", isOn: $preferences.isDoNotDisturbActive)
                
                if preferences.isDoNotDisturbActive {
                    DatePicker(
                        "Until",
                        selection: .constant(Date()),
                        displayedComponents: [.hourAndMinute]
                    )
                }
            }
            
            Section("Sound & Haptics") {
                HStack {
                    Text("Notification Sound")
                    Spacer()
                    Button("Default") {
                        // Play sound preview
                    }
                    .foregroundColor(.blue)
                }
                
                Toggle("Vibration", isOn: .constant(true))
            }
        }
        .navigationTitle("Notifications")
    }
}
```

### Use Cases

- **Chat apps**: Message and mention notifications
- **Customer support**: New ticket and response alerts
- **Team collaboration**: Important update notifications
- **Social apps**: Activity and interaction notifications
- **Gaming**: Match and event notifications

---

## Summary

The **Ably Chat Swift SDK** provides a comprehensive suite of **realtime messaging features** designed for modern **iOS chat applications**. Each feature is built with **production-ready reliability**, **Swift-native APIs**, and **enterprise-grade scalability**.

### Feature Highlights

- 📨 **Complete messaging system** with real-time sync
- 👥 **Advanced presence awareness** for user activity
- ⚡ **Intelligent typing indicators** with automatic cleanup
- 😍 **Rich reaction systems** for enhanced engagement  
- 📊 **Real-time occupancy metrics** for audience insights
- 🔗 **Robust connection management** with offline support
- 🏠 **Sophisticated room lifecycle** handling
- 🔔 **Native push notifications** for user engagement

### Getting Started

1. **Installation**: Add via Swift Package Manager or CocoaPods
2. **Configuration**: Initialize with your Ably API key
3. **Implementation**: Choose features based on your use case
4. **Customization**: Adapt UI and behavior to your app's needs

For complete implementation examples and advanced patterns, see our [Use Cases Guide](USE_CASES.md) and [API Comparison](COMPARISON.md).