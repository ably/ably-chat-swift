import Ably
import AblyChat

final class MockMessagesPaginatedResult: PaginatedResult {
    typealias Item = Message

    let clientID: String
    let roomName: String
    let numberOfMockMessages: Int

    var items: [Item] {
        Array(repeating: 0, count: numberOfMockMessages).map { _ in
            Message(
                serial: "\(Date().timeIntervalSince1970)",
                action: .create,
                clientID: self.clientID,
                text: MockStrings.randomPhrase(),
                createdAt: Date(),
                metadata: [:],
                headers: [:],
                version: "",
                timestamp: Date(),
                operation: nil
            )
        }
    }

    var hasNext: Bool { fatalError("Not implemented") }

    var isLast: Bool { fatalError("Not implemented") }

    var next: (any PaginatedResult<Item>)? { fatalError("Not implemented") }

    var first: any PaginatedResult<Item> { fatalError("Not implemented") }

    var current: any PaginatedResult<Item> { fatalError("Not implemented") }

    init(clientID: String, roomName: String, numberOfMockMessages: Int = 3) {
        self.clientID = clientID
        self.roomName = roomName
        self.numberOfMockMessages = numberOfMockMessages
    }

    static func == (_: MockMessagesPaginatedResult, _: MockMessagesPaginatedResult) -> Bool {
        fatalError("Not implemented")
    }
}

enum MockStrings {
    static let names = ["Alice", "Bob", "Charlie", "Dave", "Eve"]

    static func randomWord(length: Int = Int.random(in: 1 ... 10)) -> String {
        var word = ""
        for _ in 0 ..< length {
            let char = String(format: "%c", Int.random(in: 97 ..< 123))
            word += char
        }
        return word
    }

    static func randomPhrase(length: Int = Int.random(in: 1 ... 10)) -> String {
        var phrase = ""
        for _ in 0 ..< length {
            phrase += randomWord() + " "
        }
        phrase += Int.random(in: 1 ... 100) % 5 == 0 ? "😆" : ""
        return phrase.count % 33 == 0 ? "Bingo! 😂" : phrase
    }
}

enum ReactionType: String, CaseIterable {
    case like, dislike, lol, rofl, ok, idk

    var emoji: String {
        switch self {
        case .like:
            "👍"
        case .dislike:
            "👎"
        case .lol:
            "😆"
        case .rofl:
            "😂"
        case .ok:
            "👌"
        case .idk:
            "🤷‍♀️"
        }
    }
}

extension RoomReaction {
    var displayedText: String {
        type
    }
}

enum Emoji {
    static func random() -> String {
        let emojiRange = 0x1F600 ... 0x1F64F // All Emoticons
//        let emojiRange = 0x1F600...0x1F607 // Smiles
        let randomScalar = UnicodeScalar(Int.random(in: emojiRange))!
        return String(randomScalar)
    }

    static func all() -> [String] {
        let emojiRange = 0x1F600 ... 0x1F64F // All emoticons
        return emojiRange.map { String(UnicodeScalar($0)!) }
    }

    static func smiles() -> [String] {
        let emojiRange = 0x1F600 ... 0x1F607 // Smiles
        return emojiRange.map { String(UnicodeScalar($0)!) }
    }
}
