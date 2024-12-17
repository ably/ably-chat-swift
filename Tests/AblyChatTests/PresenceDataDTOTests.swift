@testable import AblyChat
import Testing

struct PresenceDataDTOTests {
    // MARK: - JSONDecodable

    @Test(arguments: [
        // If the `userCustomData` key is missing (indicating that no data was passed when performing the presence operation), then the DTO’s `userCustomData` should be nil
        (jsonValue: [:], expectedResult: .init(userCustomData: nil)),
        // Confirm that an arbitrary non-`.null` userCustomData is extracted correctly
        (jsonValue: ["userCustomData": "hello"], expectedResult: .init(userCustomData: "hello")),
        // Confirm that `.null` userCustomData is treated like any other JSON value
        (jsonValue: ["userCustomData": .null], expectedResult: .init(userCustomData: .null)),
    ] as[(jsonValue: JSONValue, expectedResult: PresenceDataDTO)])
    func initWithJSONValue(jsonValue: JSONValue, expectedResult: PresenceDataDTO) throws {
        #expect(try PresenceDataDTO(jsonValue: jsonValue) == expectedResult)
    }

    @Test
    func initWithJSONValue_failsIfNotObject() {
        #expect(throws: JSONValueDecodingError.self) {
            try PresenceDataDTO(jsonValue: "hello")
        }
    }

    // MARK: - JSONCodable

    @Test(
        arguments: [
            // If user doesn’t pass any data to the presence operation, the resulting JSON object should contain no `userCustomData` key
            (userCustomData: nil, expectedJSONObject: [:]),
            // Confirm that an arbitrary non-`.null` JSON value is treated correctly
            (userCustomData: "hello", expectedJSONObject: ["userCustomData": "hello"]),
            // Confirm that `.null` is treated like any other JSON value; i.e. if the user passes `.null` as the data of a presence operation, then the resulting JSON object has `"userCustomData": .null`
            (userCustomData: .null, expectedJSONObject: ["userCustomData": .null]),
        ] as[(userCustomData: PresenceData?, expectedJSONObject: [String: JSONValue])]
    )
    func toJSONValue(userCustomData: PresenceData?, expectedJSONObject: [String: JSONValue]) {
        let dto = PresenceDataDTO(userCustomData: userCustomData)
        #expect(dto.toJSONValue == .object(expectedJSONObject))
    }
}
