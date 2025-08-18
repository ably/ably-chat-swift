//
//  RoomManagement.swift
//  Ably Chat Swift SDK Examples
//
//  Room operations including creating and joining rooms, room options configuration, room lifecycle management, and multi-room handling
//  This example demonstrates comprehensive room management with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Room Creation and Configuration

/// Comprehensive examples for managing chat rooms
class RoomManager {
    private let chatClient: ChatClient
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
    }
    
    // MARK: - Basic Room Operations
    
    /// Create or get a basic room with default options
    /// - Parameter roomName: Name of the room
    /// - Returns: Configured room
    func getBasicRoom(name roomName: String) async throws -> Room {
        let room = try await chatClient.rooms.get(
            roomName: roomName,
            options: RoomOptions()
        )
        
        print("✅ Created/retrieved basic room: \(roomName)")
        return room
    }
    
    /// Create a room with all features enabled
    /// - Parameter roomName: Name of the room
    /// - Returns: Fully configured room
    func getFullFeaturedRoom(name roomName: String) async throws -> Room {
        let options = RoomOptions(
            messages: MessagesOptions(
                rawMessageReactions: true,
                defaultMessageReactionType: .distinct
            ),
            presence: PresenceOptions(
                enableEvents: true
            ),
            typing: TypingOptions(
                heartbeatThrottle: 5.0 // 5 seconds
            ),
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(
                enableEvents: true
            )
        )
        
        let room = try await chatClient.rooms.get(roomName: roomName, options: options)
        
        print("✅ Created full-featured room: \(roomName)")
        print("   - Messages: ✅ (with raw reactions)")
        print("   - Presence: ✅")
        print("   - Typing: ✅ (5s throttle)")
        print("   - Reactions: ✅")
        print("   - Occupancy: ✅")
        
        return room
    }
    
    /// Create a messages-only room (minimal configuration)
    /// - Parameter roomName: Name of the room
    /// - Returns: Messages-only room
    func getMessagesOnlyRoom(name roomName: String) async throws -> Room {
        let options = RoomOptions(
            messages: MessagesOptions(),
            presence: PresenceOptions(enableEvents: false),
            typing: TypingOptions(),
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(enableEvents: false)
        )
        
        let room = try await chatClient.rooms.get(roomName: roomName, options: options)
        
        print("✅ Created messages-only room: \(roomName)")
        return room
    }
    
    /// Create a room for high-volume scenarios
    /// - Parameter roomName: Name of the room
    /// - Returns: Optimized room for high volume
    func getHighVolumeRoom(name roomName: String) async throws -> Room {
        let options = RoomOptions(
            messages: MessagesOptions(
                rawMessageReactions: false, // Reduce message volume
                defaultMessageReactionType: .distinct
            ),
            presence: PresenceOptions(enableEvents: false), // Disable for performance
            typing: TypingOptions(heartbeatThrottle: 15.0), // Longer throttle
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(enableEvents: false)
        )
        
        let room = try await chatClient.rooms.get(roomName: roomName, options: options)
        
        print("✅ Created high-volume optimized room: \(roomName)")
        return room
    }
    
    /// Create a room for customer support scenarios
    /// - Parameter roomName: Name of the room
    /// - Returns: Support-optimized room
    func getSupportRoom(name roomName: String) async throws -> Room {
        let options = RoomOptions(
            messages: MessagesOptions(
                rawMessageReactions: true,
                defaultMessageReactionType: .unique // Only one reaction per user
            ),
            presence: PresenceOptions(enableEvents: true), // Track agent presence
            typing: TypingOptions(heartbeatThrottle: 3.0), // Fast typing updates
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(enableEvents: true) // Monitor room occupancy
        )
        
        let room = try await chatClient.rooms.get(roomName: roomName, options: options)
        
        print("✅ Created support room: \(roomName)")
        return room
    }
    
    // MARK: - Room Lifecycle Management
    
    /// Attach to a room to start receiving events
    /// - Parameter room: Room to attach to
    func attachToRoom(_ room: Room) async throws {
        print("🔌 Attaching to room: \(room.name)")
        
        try await room.attach()
        
        print("✅ Successfully attached to room: \(room.name)")
        print("   Status: \(room.status)")
    }
    
    /// Detach from a room to stop receiving events
    /// - Parameter room: Room to detach from
    func detachFromRoom(_ room: Room) async throws {
        print("🔌 Detaching from room: \(room.name)")
        
        try await room.detach()
        
        print("✅ Successfully detached from room: \(room.name)")
        print("   Status: \(room.status)")
    }
    
    /// Attach to room with retry logic
    /// - Parameters:
    ///   - room: Room to attach to
    ///   - maxRetries: Maximum retry attempts
    ///   - retryDelay: Delay between retries
    func attachToRoomWithRetry(
        _ room: Room,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0
    ) async throws {
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                try await attachToRoom(room)
                return // Success
            } catch {
                attempt += 1
                print("❌ Attach attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    print("⏳ Retrying in \(retryDelay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                } else {
                    print("❌ All attach attempts failed")
                    throw error
                }
            }
        }
    }
    
    /// Release a room to free up resources
    /// - Parameter roomName: Name of the room to release
    func releaseRoom(name roomName: String) async {
        print("🗑️ Releasing room: \(roomName)")
        
        await chatClient.rooms.release(roomName: roomName)
        
        print("✅ Successfully released room: \(roomName)")
    }
}

// MARK: - Room Status Monitoring

/// Monitor and handle room status changes
class RoomStatusMonitor {
    private let room: Room
    private var statusSubscription: StatusSubscriptionProtocol?
    private var discontinuitySubscription: StatusSubscriptionProtocol?
    
    init(room: Room) {
        self.room = room
    }
    
    /// Start monitoring room status
    func startMonitoring() {
        print("📊 Starting room status monitoring for: \(room.name)")
        
        // Monitor status changes
        statusSubscription = room.onStatusChange { statusChange in
            self.handleStatusChange(statusChange)
        }
        
        // Monitor discontinuity events
        discontinuitySubscription = room.onDiscontinuity { discontinuityEvent in
            self.handleDiscontinuity(discontinuityEvent)
        }
        
        print("✅ Room status monitoring started")
        print("   Current status: \(room.status)")
    }
    
    /// Stop monitoring room status
    func stopMonitoring() {
        print("📊 Stopping room status monitoring for: \(room.name)")
        
        statusSubscription?.off()
        discontinuitySubscription?.off()
        statusSubscription = nil
        discontinuitySubscription = nil
        
        print("✅ Room status monitoring stopped")
    }
    
    /// Handle room status changes
    private func handleStatusChange(_ statusChange: RoomStatusChange) {
        print("📊 Room status changed:")
        print("   Room: \(room.name)")
        print("   Previous: \(statusChange.previous)")
        print("   Current: \(statusChange.current)")
        
        switch statusChange.current {
        case .attached:
            print("   ✅ Room is now attached and ready")
        case .detached:
            print("   ⏸️ Room is now detached")
        case .attaching:
            print("   🔄 Room is attaching...")
        case .detaching:
            print("   🔄 Room is detaching...")
        case .suspended(let error):
            print("   ⚠️ Room is suspended: \(error)")
        case .failed(let error):
            print("   ❌ Room failed: \(error)")
        case .initialized:
            print("   🆕 Room is initialized")
        case .releasing:
            print("   🔄 Room is releasing...")
        case .released:
            print("   ✅ Room has been released")
        }
    }
    
    /// Handle discontinuity events
    private func handleDiscontinuity(_ discontinuityEvent: DiscontinuityEvent) {
        print("⚠️ Room discontinuity detected:")
        print("   Room: \(room.name)")
        print("   Type: \(discontinuityEvent)")
        
        // Handle discontinuity based on your app's needs
        // This might involve refreshing data, notifying users, etc.
    }
    
    /// Get current room status
    func getCurrentStatus() -> RoomStatus {
        return room.status
    }
    
    /// Check if room is ready for operations
    func isRoomReady() -> Bool {
        switch room.status {
        case .attached:
            return true
        default:
            return false
        }
    }
    
    /// Wait for room to be attached
    /// - Parameter timeout: Maximum time to wait
    func waitForAttached(timeout: TimeInterval = 30.0) async throws {
        let startTime = Date()
        
        while !isRoomReady() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw RoomError.attachTimeout
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("✅ Room \(room.name) is now ready")
    }
}

// MARK: - Multi-Room Manager

/// Manage multiple chat rooms simultaneously
@MainActor
class MultiRoomManager: ObservableObject {
    @Published var rooms: [String: Room] = [:]
    @Published var roomStatuses: [String: RoomStatus] = [:]
    
    private let roomManager: RoomManager
    private var statusMonitors: [String: RoomStatusMonitor] = [:]
    
    init(chatClient: ChatClient) {
        self.roomManager = RoomManager(chatClient: chatClient)
    }
    
    /// Join multiple rooms
    /// - Parameter roomNames: Array of room names to join
    func joinRooms(_ roomNames: [String]) async throws {
        print("🏢 Joining \(roomNames.count) rooms...")
        
        for roomName in roomNames {
            do {
                let room = try await roomManager.getFullFeaturedRoom(name: roomName)
                
                // Setup status monitoring
                let statusMonitor = RoomStatusMonitor(room: room)
                statusMonitors[roomName] = statusMonitor
                statusMonitor.startMonitoring()
                
                // Attach to room
                try await roomManager.attachToRoom(room)
                
                // Store room and status
                rooms[roomName] = room
                roomStatuses[roomName] = room.status
                
                print("✅ Successfully joined room: \(roomName)")
                
            } catch {
                print("❌ Failed to join room \(roomName): \(error)")
                throw error
            }
        }
        
        print("🎉 Successfully joined all \(roomNames.count) rooms")
    }
    
    /// Leave a specific room
    /// - Parameter roomName: Name of room to leave
    func leaveRoom(_ roomName: String) async throws {
        guard let room = rooms[roomName] else {
            print("⚠️ Room '\(roomName)' not found")
            return
        }
        
        print("🚪 Leaving room: \(roomName)")
        
        // Stop monitoring
        statusMonitors[roomName]?.stopMonitoring()
        statusMonitors.removeValue(forKey: roomName)
        
        // Detach from room
        try await roomManager.detachFromRoom(room)
        
        // Remove from collections
        rooms.removeValue(forKey: roomName)
        roomStatuses.removeValue(forKey: roomName)
        
        print("✅ Successfully left room: \(roomName)")
    }
    
    /// Leave all rooms
    func leaveAllRooms() async {
        print("🚪 Leaving all rooms...")
        
        let roomNames = Array(rooms.keys)
        
        for roomName in roomNames {
            do {
                try await leaveRoom(roomName)
            } catch {
                print("❌ Error leaving room \(roomName): \(error)")
            }
        }
        
        print("✅ Left all rooms")
    }
    
    /// Get room by name
    /// - Parameter roomName: Name of the room
    /// - Returns: Room if found
    func getRoom(_ roomName: String) -> Room? {
        return rooms[roomName]
    }
    
    /// Get all ready rooms
    /// - Returns: Dictionary of ready rooms
    func getReadyRooms() -> [String: Room] {
        return rooms.filter { _, room in
            switch room.status {
            case .attached:
                return true
            default:
                return false
            }
        }
    }
    
    /// Get room count by status
    /// - Returns: Count of rooms by status
    func getRoomCountByStatus() -> [String: Int] {
        var counts: [String: Int] = [:]
        
        for (_, status) in roomStatuses {
            let statusKey = "\(status)"
            counts[statusKey, default: 0] += 1
        }
        
        return counts
    }
    
    /// Update room status (called by status monitors)
    func updateRoomStatus(_ roomName: String, status: RoomStatus) {
        roomStatuses[roomName] = status
    }
}

// MARK: - Room Feature Manager

/// Manage specific features within rooms
class RoomFeatureManager {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    /// Check which features are enabled for the room
    /// - Returns: Dictionary of feature availability
    func getEnabledFeatures() -> [String: Bool] {
        let options = room.options
        
        return [
            "messages": true, // Always enabled
            "presence": options.presence.enableEvents,
            "typing": true, // Always available
            "reactions": true, // Always available
            "occupancy": options.occupancy.enableEvents,
            "messageReactions": options.messages.rawMessageReactions
        ]
    }
    
    /// Print room configuration summary
    func printRoomSummary() {
        print("📋 Room Configuration Summary:")
        print("   Name: \(room.name)")
        print("   Status: \(room.status)")
        
        let features = getEnabledFeatures()
        print("   Features:")
        for (feature, enabled) in features {
            let status = enabled ? "✅" : "❌"
            print("     \(status) \(feature)")
        }
        
        print("   Options:")
        print("     Typing throttle: \(room.options.typing.heartbeatThrottle)s")
        print("     Default reaction type: \(room.options.messages.defaultMessageReactionType)")
    }
    
    /// Get feature usage recommendations
    /// - Returns: Array of recommendations
    func getRecommendations() -> [String] {
        var recommendations: [String] = []
        let options = room.options
        
        if !options.presence.enableEvents {
            recommendations.append("Consider enabling presence events to track online users")
        }
        
        if !options.occupancy.enableEvents {
            recommendations.append("Enable occupancy events to monitor room usage")
        }
        
        if options.typing.heartbeatThrottle > 10 {
            recommendations.append("Consider reducing typing throttle for more responsive indicators")
        }
        
        if !options.messages.rawMessageReactions {
            recommendations.append("Enable raw message reactions for real-time reaction events")
        }
        
        return recommendations
    }
}

// MARK: - Room Templates

/// Pre-configured room templates for common use cases
enum RoomTemplate {
    case general
    case support
    case announcements
    case gaming
    case collaboration
    case privateChat
    
    var options: RoomOptions {
        switch self {
        case .general:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: true,
                    defaultMessageReactionType: .distinct
                ),
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 8.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: true)
            )
            
        case .support:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: true,
                    defaultMessageReactionType: .unique
                ),
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 3.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: true)
            )
            
        case .announcements:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: true,
                    defaultMessageReactionType: .multiple
                ),
                presence: PresenceOptions(enableEvents: false),
                typing: TypingOptions(heartbeatThrottle: 15.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: true)
            )
            
        case .gaming:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: false, // High volume
                    defaultMessageReactionType: .distinct
                ),
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 2.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: true)
            )
            
        case .collaboration:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: true,
                    defaultMessageReactionType: .distinct
                ),
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 5.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: true)
            )
            
        case .privateChat:
            return RoomOptions(
                messages: MessagesOptions(
                    rawMessageReactions: true,
                    defaultMessageReactionType: .unique
                ),
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 4.0),
                reactions: RoomReactionsOptions(),
                occupancy: OccupancyOptions(enableEvents: false)
            )
        }
    }
    
    var description: String {
        switch self {
        case .general:
            return "General purpose chat room with all features enabled"
        case .support:
            return "Customer support room with fast typing and unique reactions"
        case .announcements:
            return "Announcement room optimized for broadcast messages"
        case .gaming:
            return "Gaming room optimized for high-frequency messages"
        case .collaboration:
            return "Team collaboration room with balanced features"
        case .privateChat:
            return "Private chat room with enhanced presence tracking"
        }
    }
}

// MARK: - Room Template Manager

/// Create rooms from templates
class RoomTemplateManager {
    private let chatClient: ChatClient
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
    }
    
    /// Create room from template
    /// - Parameters:
    ///   - roomName: Name of the room
    ///   - template: Room template to use
    /// - Returns: Configured room
    func createRoomFromTemplate(
        name roomName: String,
        template: RoomTemplate
    ) async throws -> Room {
        let room = try await chatClient.rooms.get(
            roomName: roomName,
            options: template.options
        )
        
        print("✅ Created room '\(roomName)' from template: \(template)")
        print("   Description: \(template.description)")
        
        return room
    }
    
    /// List all available templates
    func listTemplates() {
        print("📋 Available Room Templates:")
        print("   1. General: \(RoomTemplate.general.description)")
        print("   2. Support: \(RoomTemplate.support.description)")
        print("   3. Announcements: \(RoomTemplate.announcements.description)")
        print("   4. Gaming: \(RoomTemplate.gaming.description)")
        print("   5. Collaboration: \(RoomTemplate.collaboration.description)")
        print("   6. Private Chat: \(RoomTemplate.privateChat.description)")
    }
}

// MARK: - Room Errors

enum RoomError: LocalizedError {
    case attachTimeout
    case roomNotFound(String)
    case invalidConfiguration
    case alreadyJoined(String)
    
    var errorDescription: String? {
        switch self {
        case .attachTimeout:
            return "Room attach operation timed out"
        case .roomNotFound(let name):
            return "Room '\(name)' not found"
        case .invalidConfiguration:
            return "Invalid room configuration"
        case .alreadyJoined(let name):
            return "Already joined room '\(name)'"
        }
    }
}

// MARK: - Complete Room Management Example

/// Complete example demonstrating all room management features
class CompleteRoomManagementExample {
    
    func runRoomManagementExample(chatClient: ChatClient) async {
        print("🏢 Running Room Management Example")
        
        let roomManager = RoomManager(chatClient: chatClient)
        let templateManager = RoomTemplateManager(chatClient: chatClient)
        let multiRoomManager = MultiRoomManager(chatClient: chatClient)
        
        do {
            // 1. Create rooms with different configurations
            print("\n1. Creating rooms with different configurations:")
            
            let basicRoom = try await roomManager.getBasicRoom(name: "basic-chat")
            let fullRoom = try await roomManager.getFullFeaturedRoom(name: "full-featured")
            let supportRoom = try await templateManager.createRoomFromTemplate(
                name: "customer-support",
                template: .support
            )
            
            // 2. Attach to rooms
            print("\n2. Attaching to rooms:")
            
            try await roomManager.attachToRoom(basicRoom)
            try await roomManager.attachToRoomWithRetry(fullRoom)
            try await roomManager.attachToRoom(supportRoom)
            
            // 3. Setup room status monitoring
            print("\n3. Setting up room monitoring:")
            
            let statusMonitor = RoomStatusMonitor(room: fullRoom)
            statusMonitor.startMonitoring()
            
            // 4. Feature analysis
            print("\n4. Analyzing room features:")
            
            let featureManager = RoomFeatureManager(room: supportRoom)
            featureManager.printRoomSummary()
            
            let recommendations = featureManager.getRecommendations()
            if !recommendations.isEmpty {
                print("   Recommendations:")
                for recommendation in recommendations {
                    print("     • \(recommendation)")
                }
            }
            
            // 5. Multi-room management
            print("\n5. Multi-room management:")
            
            await multiRoomManager.joinRooms([
                "room-alpha",
                "room-beta", 
                "room-gamma"
            ])
            
            let readyRooms = multiRoomManager.getReadyRooms()
            print("   Ready rooms: \(readyRooms.keys.joined(separator: ", "))")
            
            let statusCounts = multiRoomManager.getRoomCountByStatus()
            print("   Room status counts: \(statusCounts)")
            
            // 6. Room templates
            print("\n6. Available room templates:")
            templateManager.listTemplates()
            
            // Wait to observe events
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            // 7. Cleanup
            print("\n7. Cleaning up:")
            
            statusMonitor.stopMonitoring()
            
            try await roomManager.detachFromRoom(basicRoom)
            try await roomManager.detachFromRoom(fullRoom)
            try await roomManager.detachFromRoom(supportRoom)
            
            await multiRoomManager.leaveAllRooms()
            
            // Release rooms
            await roomManager.releaseRoom(name: "basic-chat")
            await roomManager.releaseRoom(name: "full-featured")
            await roomManager.releaseRoom(name: "customer-support")
            
            print("✅ Room management example completed!")
            
        } catch {
            print("❌ Room management example failed: \(error)")
        }
    }
}

/*
USAGE:

1. Basic room operations:
   let roomManager = RoomManager(chatClient: chatClient)
   let room = try await roomManager.getBasicRoom(name: "general")
   try await roomManager.attachToRoom(room)

2. Room with specific features:
   let room = try await roomManager.getFullFeaturedRoom(name: "team-chat")
   let supportRoom = try await roomManager.getSupportRoom(name: "support")

3. Room templates:
   let templateManager = RoomTemplateManager(chatClient: chatClient)
   let room = try await templateManager.createRoomFromTemplate(
       name: "gaming-lobby",
       template: .gaming
   )

4. Room status monitoring:
   let statusMonitor = RoomStatusMonitor(room: room)
   statusMonitor.startMonitoring()
   
   // Check if ready for operations
   try await statusMonitor.waitForAttached()

5. Multi-room management:
   @StateObject private var multiRoomManager = MultiRoomManager(chatClient: chatClient)
   
   .task {
       try await multiRoomManager.joinRooms(["room1", "room2", "room3"])
   }
   
   .onChange(of: multiRoomManager.roomStatuses) { statuses in
       // React to room status changes
   }

6. Room feature analysis:
   let featureManager = RoomFeatureManager(room: room)
   let features = featureManager.getEnabledFeatures()
   let recommendations = featureManager.getRecommendations()

7. Room lifecycle with proper cleanup:
   // Attach
   try await roomManager.attachToRoom(room)
   
   // Use room...
   
   // Cleanup
   try await roomManager.detachFromRoom(room)
   await roomManager.releaseRoom(name: roomName)

8. Complete example:
   Task {
       await CompleteRoomManagementExample().runRoomManagementExample(
           chatClient: chatClient
       )
   }

FEATURES COVERED:
- Room creation with different configurations
- Room lifecycle management (attach/detach)
- Room status monitoring and discontinuity handling
- Multi-room management
- Room feature analysis and recommendations
- Room templates for common use cases
- Proper resource cleanup and release
- Error handling and retry logic
- SwiftUI integration patterns
- Room configuration optimization for different scenarios
*/