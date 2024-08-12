public protocol Room: AnyObject, Sendable {
    var roomID: String { get }
    var messages: any Messages { get }
    var presence: any Presence { get throws }
    var reactions: any RoomReactions { get throws }
    var typing: any Typing { get throws }
    var occupancy: any Occupancy { get throws }
    var status: any RoomStatus { get }
    func attach() async throws
    func detach() async throws
    var options: RoomOptions { get }
}
