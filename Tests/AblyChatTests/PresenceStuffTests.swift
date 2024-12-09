@testable import AblyChat
import Testing

// TODO: Put stuff in right place

struct PresenceDataDTOTests {
    // MARK: Creating from an argument

    // MARK: Converting to JSON object

    @Test(
        arguments: [
            (userCustomData: .notSupplied, expectedJSONObject: [:]),
            (userCustomData: .supplied(.null), expectedJSONObject: ["userCustomData": .null]),
            // TODO: Fill out with the other values as we fill out JSONValue enum (but they're not very interesting)
        ] as[(userCustomData: PresenceDataDTO.UserCustomData, expectedJSONObject: [String: JSONValue])]
    )
    func toJSONObject(userCustomData: PresenceDataDTO.UserCustomData, expectedJSONObject: [String: JSONValue]) {
        let dto = PresenceDataDTO(userCustomData: userCustomData)
        #expect(dto.toJSONObject == expectedJSONObject)
    }
}
