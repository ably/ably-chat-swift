//
//  PresenceAndTyping.swift
//  Ably Chat Swift SDK Examples
//
//  Presence and typing indicators including entering/leaving presence, tracking online users, and typing implementation
//  This example demonstrates comprehensive user presence and typing features
//

import AblyChat
import Ably
import Foundation

// MARK: - Presence Management

/// Comprehensive examples for handling user presence in Ably Chat
class PresenceHandler {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    // MARK: - Basic Presence Operations
    
    /// Enter presence with basic data
    /// - Parameter userData: Optional data to associate with presence
    func enterPresence(userData: PresenceData? = nil) async throws {
        if let userData = userData {
            try await room.presence.enter(data: userData)
            print("✅ Entered presence with data: \(userData)")
        } else {
            try await room.presence.enter()
            print("✅ Entered presence without data")
        }
    }
    
    /// Update presence data
    /// - Parameter newData: New presence data
    func updatePresence(newData: PresenceData) async throws {
        try await room.presence.update(data: newData)
        print("🔄 Updated presence data: \(newData)")
    }
    
    /// Leave presence
    /// - Parameter farewell: Optional farewell data
    func leavePresence(farewell: PresenceData? = nil) async throws {
        if let farewell = farewell {
            try await room.presence.leave(data: farewell)
            print("👋 Left presence with farewell: \(farewell)")
        } else {
            try await room.presence.leave()
            print("👋 Left presence")
        }
    }
    
    /// Enter presence with rich user data
    /// - Parameters:
    ///   - name: User's display name
    ///   - status: User's status
    ///   - avatar: Avatar URL
    ///   - metadata: Additional user metadata
    func enterPresenceWithUserInfo(
        name: String,
        status: String = "online",
        avatar: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        var presenceData: [String: Any] = [
            "name": name,
            "status": status,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let avatar = avatar {
            presenceData["avatar"] = avatar
        }
        
        if let metadata = metadata {
            presenceData["metadata"] = metadata
        }
        
        try await room.presence.enter(data: presenceData)
        
        print("✅ Entered presence as '\(name)' with status '\(status)'")
    }
    
    // MARK: - Presence Queries
    
    /// Get all present members
    /// - Returns: Array of current presence members
    func getCurrentMembers() async throws -> [PresenceMember] {
        let members = try await room.presence.get()
        
        print("👥 Current members (\(members.count)):")
        for member in members {
            let name = (member.data as? [String: Any])?["name"] as? String ?? member.clientID
            let status = (member.data as? [String: Any])?["status"] as? String ?? "unknown"
            print("   - \(name) (\(member.clientID)): \(status)")
        }
        
        return members
    }
    
    /// Get members with specific parameters
    /// - Parameter params: Query parameters for presence
    /// - Returns: Filtered presence members
    func getMembersWithParams(params: PresenceParams) async throws -> [PresenceMember] {
        let members = try await room.presence.get(params: params)
        
        print("👥 Filtered members (\(members.count)) with params:")
        if let clientId = params.clientID {
            print("   Client ID filter: \(clientId)")
        }
        if let connectionId = params.connectionID {
            print("   Connection ID filter: \(connectionId)")
        }
        print("   Wait for sync: \(params.waitForSync)")
        
        return members
    }
    
    /// Check if specific user is present
    /// - Parameter clientId: Client ID to check
    /// - Returns: True if user is present
    func isUserOnline(clientId: String) async throws -> Bool {
        let isPresent = try await room.presence.isUserPresent(clientID: clientId)
        
        print("🔍 User '\(clientId)' is \(isPresent ? "online" : "offline")")
        
        return isPresent
    }
    
    /// Get online users count
    /// - Returns: Number of currently online users
    func getOnlineUsersCount() async throws -> Int {
        let members = try await room.presence.get()
        print("📊 Total online users: \(members.count)")
        return members.count
    }
    
    // MARK: - Presence Event Subscription
    
    /// Subscribe to presence events using callback
    /// - Parameter onPresenceEvent: Callback for presence events
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToPresenceEvents(
        onPresenceEvent: @escaping (PresenceEvent) -> Void
    ) -> SubscriptionProtocol {
        let subscription = room.presence.subscribe(
            events: [.enter, .leave, .update, .present]
        ) { presenceEvent in
            let name = (presenceEvent.member.data as? [String: Any])?["name"] as? String ?? presenceEvent.member.clientID
            
            switch presenceEvent.type {
            case .enter:
                print("🟢 \(name) joined the room")
            case .leave:
                print("🔴 \(name) left the room")
            case .update:
                print("🔄 \(name) updated their presence")
            case .present:
                print("👁️ \(name) is present (initial sync)")
            }
            
            onPresenceEvent(presenceEvent)
        }
        
        return subscription
    }
    
    /// Subscribe to specific presence events
    /// - Parameters:
    ///   - events: Array of event types to subscribe to
    ///   - callback: Event handler
    /// - Returns: Subscription
    @discardableResult
    func subscribeToSpecificEvents(
        events: [PresenceEventType],
        callback: @escaping (PresenceEvent) -> Void
    ) -> SubscriptionProtocol {
        return room.presence.subscribe(events: events, callback)
    }
    
    /// Subscribe to presence events using AsyncSequence
    /// - Parameter events: Events to subscribe to
    /// - Returns: AsyncSequence for presence events
    func subscribeToPresenceEventsAsync(
        events: [PresenceEventType] = [.enter, .leave, .update, .present]
    ) -> SubscriptionAsyncSequence<PresenceEvent> {
        let subscription = room.presence.subscribe(events: events)
        
        // Process events in background
        Task {
            for await presenceEvent in subscription {
                await MainActor.run {
                    let name = (presenceEvent.member.data as? [String: Any])?["name"] as? String ?? presenceEvent.member.clientID
                    print("📡 Async presence event: \(presenceEvent.type) for \(name)")
                }
            }
        }
        
        return subscription
    }
}

// MARK: - Typing Indicators

/// Comprehensive examples for handling typing indicators
class TypingHandler {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    // MARK: - Basic Typing Operations
    
    /// Start typing indicator
    func startTyping() async throws {
        try await room.typing.keystroke()
        print("⌨️ Started typing indicator")
    }
    
    /// Stop typing indicator
    func stopTyping() async throws {
        try await room.typing.stop()
        print("⏹️ Stopped typing indicator")
    }
    
    /// Get current typers
    /// - Returns: Set of client IDs currently typing
    func getCurrentTypers() async throws -> Set<String> {
        let typers = try await room.typing.get()
        
        print("⌨️ Currently typing (\(typers.count)): \(typers.joined(separator: ", "))")
        
        return typers
    }
    
    // MARK: - Typing Event Subscription
    
    /// Subscribe to typing events using callback
    /// - Parameter onTypingEvent: Callback for typing events
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToTypingEvents(
        onTypingEvent: @escaping (TypingSetEvent) -> Void
    ) -> SubscriptionProtocol {
        let subscription = room.typing.subscribe { typingEvent in
            print("⌨️ Typing event:")
            print("   Type: \(typingEvent.type)")
            print("   Currently typing: \(typingEvent.currentlyTyping.joined(separator: ", "))")
            print("   Change: \(typingEvent.change.clientId) - \(typingEvent.change.type)")
            
            onTypingEvent(typingEvent)
        }
        
        return subscription
    }
    
    /// Subscribe to typing events using AsyncSequence
    /// - Returns: AsyncSequence for typing events
    func subscribeToTypingEventsAsync() -> SubscriptionAsyncSequence<TypingSetEvent> {
        let subscription = room.typing.subscribe()
        
        // Process events in background
        Task {
            for await typingEvent in subscription {
                await MainActor.run {
                    let typingUsers = typingEvent.currentlyTyping
                    if typingUsers.isEmpty {
                        print("⌨️ No one is typing")
                    } else {
                        print("⌨️ \(typingUsers.joined(separator: ", ")) \(typingUsers.count == 1 ? "is" : "are") typing...")
                    }
                }
            }
        }
        
        return subscription
    }
    
    /// Subscribe with custom buffering policy
    /// - Parameter bufferingPolicy: Buffering policy for events
    /// - Returns: AsyncSequence with custom buffering
    func subscribeToTypingWithBuffering(
        bufferingPolicy: BufferingPolicy
    ) -> SubscriptionAsyncSequence<TypingSetEvent> {
        return room.typing.subscribe(bufferingPolicy: bufferingPolicy)
    }
}

// MARK: - Advanced Typing Management

/// Advanced typing management with automatic cleanup and smart indicators
class SmartTypingManager {
    private let typingHandler: TypingHandler
    private var typingTimer: Timer?
    private var isCurrentlyTyping = false
    
    init(typingHandler: TypingHandler) {
        self.typingHandler = typingHandler
    }
    
    /// Handle keystroke with automatic timeout
    /// - Parameter timeoutInterval: How long to show typing before auto-stop
    func handleKeystroke(timeoutInterval: TimeInterval = 10.0) async throws {
        // Start typing if not already typing
        if !isCurrentlyTyping {
            try await typingHandler.startTyping()
            isCurrentlyTyping = true
        }
        
        // Reset the timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            Task {
                try? await self?.stopTypingIndicator()
            }
        }
    }
    
    /// Stop typing indicator
    func stopTypingIndicator() async throws {
        guard isCurrentlyTyping else { return }
        
        try await typingHandler.stopTyping()
        isCurrentlyTyping = false
        typingTimer?.invalidate()
        typingTimer = nil
    }
    
    /// Handle message sent (automatically stop typing)
    func handleMessageSent() async throws {
        try await stopTypingIndicator()
    }
    
    deinit {
        typingTimer?.invalidate()
    }
}

// MARK: - Combined Presence and Typing UI

/// Combined handler for both presence and typing for UI integration
@MainActor
class PresenceAndTypingManager: ObservableObject {
    @Published var onlineMembers: [PresenceMember] = []
    @Published var typingUsers: Set<String> = []
    @Published var currentUserStatus: String = "offline"
    
    private let presenceHandler: PresenceHandler
    private let typingHandler: TypingHandler
    private let smartTypingManager: SmartTypingManager
    
    private var presenceSubscription: SubscriptionProtocol?
    private var typingSubscription: SubscriptionProtocol?
    
    init(room: Room) {
        self.presenceHandler = PresenceHandler(room: room)
        self.typingHandler = TypingHandler(room: room)
        self.smartTypingManager = SmartTypingManager(typingHandler: typingHandler)
    }
    
    /// Initialize presence and typing monitoring
    func startMonitoring() async {
        await setupPresenceSubscription()
        setupTypingSubscription()
        await loadCurrentMembers()
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        presenceSubscription?.unsubscribe()
        typingSubscription?.unsubscribe()
        presenceSubscription = nil
        typingSubscription = nil
    }
    
    /// Enter presence with user info
    /// - Parameters:
    ///   - name: Display name
    ///   - status: User status
    ///   - avatar: Avatar URL
    func enterPresence(name: String, status: String = "online", avatar: String? = nil) async throws {
        try await presenceHandler.enterPresenceWithUserInfo(
            name: name,
            status: status,
            avatar: avatar
        )
        currentUserStatus = status
    }
    
    /// Update user status
    /// - Parameter status: New status
    func updateStatus(_ status: String) async throws {
        let userData: [String: Any] = [
            "status": status,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        try await presenceHandler.updatePresence(newData: userData)
        currentUserStatus = status
    }
    
    /// Leave presence
    func leavePresence() async throws {
        try await presenceHandler.leavePresence()
        currentUserStatus = "offline"
    }
    
    /// Handle typing keystroke
    func handleTyping() async throws {
        try await smartTypingManager.handleKeystroke()
    }
    
    /// Stop typing
    func stopTyping() async throws {
        try await smartTypingManager.stopTypingIndicator()
    }
    
    /// Handle message sent
    func handleMessageSent() async throws {
        try await smartTypingManager.handleMessageSent()
    }
    
    // MARK: - Private Setup Methods
    
    private func setupPresenceSubscription() async {
        presenceSubscription = presenceHandler.subscribeToPresenceEvents { [weak self] presenceEvent in
            Task { @MainActor in
                await self?.handlePresenceEvent(presenceEvent)
            }
        }
    }
    
    private func setupTypingSubscription() {
        typingSubscription = typingHandler.subscribeToTypingEvents { [weak self] typingEvent in
            Task { @MainActor in
                self?.typingUsers = typingEvent.currentlyTyping
            }
        }
    }
    
    private func loadCurrentMembers() async {
        do {
            onlineMembers = try await presenceHandler.getCurrentMembers()
        } catch {
            print("❌ Failed to load current members: \(error)")
        }
    }
    
    private func handlePresenceEvent(_ event: PresenceEvent) async {
        switch event.type {
        case .enter, .present:
            if !onlineMembers.contains(where: { $0.clientID == event.member.clientID }) {
                onlineMembers.append(event.member)
            }
        case .leave:
            onlineMembers.removeAll { $0.clientID == event.member.clientID }
        case .update:
            if let index = onlineMembers.firstIndex(where: { $0.clientID == event.member.clientID }) {
                onlineMembers[index] = event.member
            }
        }
    }
    
    /// Get formatted typing indicator text
    var typingIndicatorText: String {
        let count = typingUsers.count
        switch count {
        case 0:
            return ""
        case 1:
            return "\(typingUsers.first!) is typing..."
        case 2:
            return "\(typingUsers.joined(separator: " and ")) are typing..."
        default:
            return "\(count) people are typing..."
        }
    }
    
    /// Get online member names
    var onlineMemberNames: [String] {
        return onlineMembers.compactMap { member in
            (member.data as? [String: Any])?["name"] as? String ?? member.clientID
        }
    }
}

// MARK: - Presence Status Definitions

/// Common presence status definitions
enum PresenceStatus: String, CaseIterable {
    case online = "online"
    case away = "away"
    case busy = "busy"
    case offline = "offline"
    
    var emoji: String {
        switch self {
        case .online: return "🟢"
        case .away: return "🟡"
        case .busy: return "🔴"
        case .offline: return "⚫"
        }
    }
    
    var description: String {
        switch self {
        case .online: return "Online"
        case .away: return "Away"
        case .busy: return "Busy"
        case .offline: return "Offline"
        }
    }
}

// MARK: - User Presence Model

/// Enhanced user presence model
struct UserPresence {
    let clientID: String
    let name: String
    let status: PresenceStatus
    let avatar: String?
    let lastSeen: Date
    let metadata: [String: Any]?
    
    init(from member: PresenceMember) {
        clientID = member.clientID
        
        if let data = member.data as? [String: Any] {
            name = data["name"] as? String ?? member.clientID
            status = PresenceStatus(rawValue: data["status"] as? String ?? "online") ?? .online
            avatar = data["avatar"] as? String
            metadata = data["metadata"] as? [String: Any]
        } else {
            name = member.clientID
            status = .online
            avatar = nil
            metadata = nil
        }
        
        lastSeen = member.updatedAt
    }
}

// MARK: - Complete Example

/// Complete example demonstrating presence and typing features
class CompletePresenceAndTypingExample {
    
    func runExample(room: Room) async {
        print("👥 Running Presence and Typing Example")
        
        let presenceHandler = PresenceHandler(room: room)
        let typingHandler = TypingHandler(room: room)
        let manager = PresenceAndTypingManager(room: room)
        
        do {
            // 1. Setup monitoring
            print("\n1. Setting up presence and typing monitoring:")
            await manager.startMonitoring()
            
            // 2. Enter presence
            print("\n2. Entering presence:")
            try await manager.enterPresence(
                name: "Example User",
                status: PresenceStatus.online.rawValue,
                avatar: "https://example.com/avatar.jpg"
            )
            
            // 3. Demonstrate typing
            print("\n3. Demonstrating typing indicators:")
            try await manager.handleTyping()
            
            // Wait a bit to see typing indicator
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            try await manager.stopTyping()
            
            // 4. Update status
            print("\n4. Updating user status:")
            try await manager.updateStatus(PresenceStatus.away.rawValue)
            
            // 5. Show current state
            print("\n5. Current state:")
            print("   Online members: \(manager.onlineMemberNames.joined(separator: ", "))")
            print("   Current status: \(manager.currentUserStatus)")
            print("   Typing users: \(manager.typingUsers.joined(separator: ", "))")
            
            // 6. Simulate typing and message flow
            print("\n6. Simulating typing flow:")
            try await manager.handleTyping()
            print("   Started typing...")
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            try await manager.handleMessageSent()
            print("   Message sent, typing stopped")
            
            // Wait to observe events
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            // 7. Cleanup
            print("\n7. Cleaning up:")
            try await manager.leavePresence()
            await manager.stopMonitoring()
            
            print("✅ Presence and typing example completed!")
            
        } catch {
            print("❌ Presence and typing example failed: \(error)")
        }
    }
}

/*
USAGE:

1. Basic presence operations:
   let presenceHandler = PresenceHandler(room: room)
   try await presenceHandler.enterPresenceWithUserInfo(name: "John", status: "online")
   let members = try await presenceHandler.getCurrentMembers()

2. Basic typing:
   let typingHandler = TypingHandler(room: room)
   try await typingHandler.startTyping()
   try await typingHandler.stopTyping()

3. Smart typing management:
   let smartTyping = SmartTypingManager(typingHandler: typingHandler)
   try await smartTyping.handleKeystroke()  // Auto-stops after timeout

4. SwiftUI integration:
   @StateObject private var presenceManager = PresenceAndTypingManager(room: room)
   
   .task {
       await presenceManager.startMonitoring()
       try await presenceManager.enterPresence(name: "User")
   }
   
   .onReceive(presenceManager.$onlineMembers) { members in
       // Update UI with online members
   }
   
   .onReceive(presenceManager.$typingUsers) { typers in
       // Show typing indicators
   }

5. Presence subscription:
   presenceHandler.subscribeToPresenceEvents { event in
       switch event.type {
       case .enter: print("User joined")
       case .leave: print("User left")
       case .update: print("User updated")
       case .present: print("User present")
       }
   }

6. Typing subscription:
   typingHandler.subscribeToTypingEvents { event in
       let typingList = event.currentlyTyping.joined(separator: ", ")
       print("Currently typing: \(typingList)")
   }

7. Complete example:
   Task {
       await CompletePresenceAndTypingExample().runExample(room: room)
   }

FEATURES COVERED:
- Basic presence operations (enter, leave, update)
- Rich presence data with user information
- Presence queries and filtering
- Real-time presence event subscription
- Basic typing indicators
- Smart typing management with auto-timeout
- Combined presence and typing for UI
- AsyncSequence support for both features
- SwiftUI integration patterns
- Comprehensive error handling
*/