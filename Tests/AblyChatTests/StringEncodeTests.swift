@testable import AblyChat
import Foundation
import Testing

struct StringEncodeTests {
    // MARK: - Basic ASCII Tests

    @Test
    func encodeBasicASCIICharacters() {
        // ASCII word characters and allowed symbols should not be encoded
        let input = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-.!~*'()"
        let result = input.encodePathSegment()
        #expect(result == input)
    }

    @Test
    func encodeSpaces() {
        let input = "hello world"
        let result = input.encodePathSegment()
        #expect(result == "hello%20world")
    }

    @Test
    func encodeSlash() {
        let input = "room/with/slash"
        let result = input.encodePathSegment()
        #expect(result == "room%2Fwith%2Fslash")
    }

    @Test
    func encodeSpecialCharacters() {
        let input = "hello@world#test"
        let result = input.encodePathSegment()
        #expect(result == "hello@world%23test")
    }

    // MARK: - UTF-8 Multi-byte Tests

    @Test
    func encodeUTF8TwoByteCharacters() {
        // © is U+00A9, which encodes as C2 A9 in UTF-8
        let input = "©"
        let result = input.encodePathSegment()
        #expect(result == "%C2%A9")
    }

    @Test
    func encodeUTF8ThreeByteCharacters() {
        // ™ is U+2122, which encodes as E2 84 A2 in UTF-8
        let input = "™"
        let result = input.encodePathSegment()
        #expect(result == "%E2%84%A2")
    }

    @Test
    func encodeEmoji() {
        // 😀 is U+1F600, which encodes as F0 9F 98 80 in UTF-8
        let input = "😀"
        let result = input.encodePathSegment()
        #expect(result == "%F0%9F%98%80")
    }

    @Test
    func encodeMixedContent() {
        let input = "Hello 世界 😀!"
        let result = input.encodePathSegment()
        // Hello and ! are unescaped
        // Space is %20
        // 世 is U+4E16 (E4 B8 96 in UTF-8)
        // 界 is U+754C (E7 95 8C in UTF-8)
        // 😀 is U+1F600 (F0 9F 98 80 in UTF-8)
        #expect(result == "Hello%20%E4%B8%96%E7%95%8C%20%F0%9F%98%80!")
    }

    // MARK: - Surrogate Pair Tests

    @Test
    func encodeValidSurrogatePairs() {
        // 𝕳 is U+1D573, which is represented as surrogate pair D835 DD73
        // It encodes as F0 9D 95 B3 in UTF-8
        let input = "𝕳"
        let result = input.encodePathSegment()
        #expect(result == "%F0%9D%95%B3")
    }

    @Test
    func encodeMultipleSurrogatePairs() {
        // 𝐀𝐁 contains two characters that require surrogate pairs
        let input = "𝐀𝐁"
        let result = input.encodePathSegment()
        // Both should be properly encoded
        #expect(result.hasPrefix("%F0%9D"))
    }

    // MARK: - Real-world Use Cases

    @Test
    func encodeRoomName() {
        let input = "room/basketball/game#1"
        let result = input.encodePathSegment()
        #expect(result == "room%2Fbasketball%2Fgame%231")
    }

    @Test
    func encodeURLComponents() {
        let input = "user@example.com"
        let result = input.encodePathSegment()
        #expect(result == "user@example.com")
    }

    @Test
    func encodeQueryString() {
        let input = "key=value&other=test"
        let result = input.encodePathSegment()
        #expect(result == "key=value&other=test")
    }

    @Test
    func encodeEmptyString() {
        let input = ""
        let result = input.encodePathSegment()
        #expect(result.isEmpty)
    }

    @Test
    func encodeOnlySpecialCharacters() {
        let input = "@#$%^&*"
        let result = input.encodePathSegment()
        // * is in alwaysUnescaped, others should be encoded
        #expect(result == "@%23$%25%5E&*")
    }

    // MARK: - Hexadecimal Uppercase Tests

    @Test
    func encodeUsesUppercaseHex() {
        // Verify that hexadecimal digits are uppercase
        let input = "ñ" // U+00F1, encodes as C3 B1 in UTF-8
        let result = input.encodePathSegment()
        #expect(result == "%C3%B1")
        // Make sure it's not lowercase
        #expect(result != "%c3%b1")
    }
}
