public protocol Rooms: AnyObject, Sendable {
    func get(roomID: String, options: RoomOptions) throws -> any Room
    func release(roomID: String) async throws
    var clientOptions: ClientOptions { get }
}
