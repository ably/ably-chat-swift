@testable import AblyChat
import Testing

enum RoomReactionDTOTests {
    struct DataTests {
        // MARK: - JSONDecodable

        @Test
        func initWithJSONValue_failsIfNotObject() {
            #expect {
                try RoomReactionDTO.Data(jsonValue: "hello")
            } throws: { error in
                isErrorInfoWithInternalErrorCase(error, .jsonValueDecodingError)
            }
        }

        @Test
        func initWithJSONValue_withNoTypeKey() {
            #expect {
                try RoomReactionDTO.Data(jsonValue: [:])
            } throws: { error in
                isErrorInfoWithInternalErrorCase(error, .jsonValueDecodingError)
            }
        }

        @Test
        func initWithJSONValue_withNoMetadataKey() throws {
            #expect(try RoomReactionDTO.Data(jsonValue: ["name": "" /* arbitrary */ ]).metadata == nil)
        }

        @Test
        func initWithJSONValue() throws {
            let data = try RoomReactionDTO.Data(
                jsonValue: [
                    "name": "someName",
                    "metadata": [
                        "someStringKey": "someStringValue",
                        "someNumberKey": 123,
                    ],
                ],
            )

            #expect(data == .init(name: "someName", metadata: ["someStringKey": "someStringValue", "someNumberKey": 123]))
        }

        // MARK: - JSONCodable

        @Test
        func toJSONValue_withNilMetadata() {
            // i.e. should create an empty object for metadata
            #expect(RoomReactionDTO.Data(name: "" /* arbitrary */, metadata: nil).toJSONValue == .object(["name": "", "metadata": .object([:])]))
        }

        @Test
        func toJSONValue() {
            let data = RoomReactionDTO.Data(name: "someName", metadata: ["someStringKey": "someStringValue", "someNumberKey": 123])

            #expect(data.toJSONValue == [
                "name": "someName",
                "metadata": [
                    "someStringKey": "someStringValue",
                    "someNumberKey": 123,
                ],
            ])
        }
    }

    struct ExtrasTests {
        // MARK: - JSONDecodable

        @Test
        func initWithJSONValue_failsIfNotObject() {
            #expect {
                try RoomReactionDTO.Extras(jsonValue: "hello")
            } throws: { error in
                isErrorInfoWithInternalErrorCase(error, .jsonValueDecodingError)
            }
        }

        @Test
        func initWithJSONValue_withNoHeadersKey() throws {
            #expect(try RoomReactionDTO.Extras(jsonValue: [:]).headers == nil)
        }

        @Test
        func initWithJSONValue() throws {
            let data = try RoomReactionDTO.Extras(
                jsonValue: [
                    "headers": [
                        "someStringKey": "someStringValue",
                        "someNumberKey": 123,
                    ],
                ],
            )

            #expect(data == .init(headers: ["someStringKey": "someStringValue", "someNumberKey": 123]))
        }

        // MARK: - JSONCodable

        @Test
        func toJSONValue_withNilHeaders() {
            // i.e. should create an empty object for headers
            // swiftlint:disable:next empty_collection_literal
            #expect(RoomReactionDTO.Extras(headers: nil).toJSONValue.objectValue?["headers"] == [:])
        }

        @Test
        func toJSONValue() {
            let data = RoomReactionDTO.Extras(headers: ["someStringKey": "someStringValue", "someNumberKey": 123])

            #expect(data.toJSONValue == [
                "headers": [
                    "someStringKey": "someStringValue",
                    "someNumberKey": 123,
                ],
                "ephemeral": true,
            ])
        }
    }
}
