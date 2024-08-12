@testable import AblyChat
import XCTest

final class AblyChatTests: XCTestCase {
    func testExample() throws {
        XCTAssertNoThrow(DefaultChatClient(realtime: MockRealtime(key: ""), clientOptions: ClientOptions()))
    }
}
