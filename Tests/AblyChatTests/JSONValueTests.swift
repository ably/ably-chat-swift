@testable import AblyChat
import Foundation
import Testing

struct JSONValueTests {
    // MARK: Conversion from ably-cocoa data

    @Test(arguments: [
        // object
        (ablyCocoaPresenceData: ["someKey": "someValue"], expectedResult: ["someKey": "someValue"]),
        // array
        (ablyCocoaPresenceData: ["someElement"], expectedResult: ["someElement"]),
        // string
        (ablyCocoaPresenceData: "someString", expectedResult: "someString"),
        // number
        (ablyCocoaPresenceData: NSNumber(value: 0), expectedResult: 0),
        (ablyCocoaPresenceData: NSNumber(value: 1), expectedResult: 1),
        (ablyCocoaPresenceData: NSNumber(value: 123), expectedResult: 123),
        (ablyCocoaPresenceData: NSNumber(value: 123.456), expectedResult: 123.456),
        // bool
        (ablyCocoaPresenceData: NSNumber(value: true), expectedResult: true),
        (ablyCocoaPresenceData: NSNumber(value: false), expectedResult: false),
        // null
        (ablyCocoaPresenceData: NSNull(), expectedResult: .null),
    ] as[(ablyCocoaPresenceData: any Sendable, expectedResult: JSONValue?)])
    func initWithAblyCocoaPresenceData(ablyCocoaData: any Sendable, expectedResult: JSONValue?) {
        #expect(JSONValue(ablyCocoaData: ablyCocoaData) == expectedResult)
    }

    // Tests that it correctly handles an object deserialized by `JSONSerialization` (which is what ably-cocoa uses for deserialization).
    @Test
    func initWithAblyCocoaData_endToEnd() throws {
        let jsonString = """
        {
          "someArray": [
            {
              "someStringKey": "someString",
              "zero": 0,
              "one": 1,
              "someIntegerKey": 123,
              "someFloatKey": 123.456,
              "someTrueKey": true,
              "someFalseKey": false,
              "someNullKey": null
            },
            "someOtherArrayElement"
          ],
          "someNestedObject": {
            "someOtherKey": "someOtherValue"
          }
        }
        """

        let ablyCocoaData = try JSONSerialization.jsonObject(with: #require(jsonString.data(using: .utf8)))

        let expected: JSONValue = [
            "someArray": [
                [
                    "someStringKey": "someString",
                    "zero": 0,
                    "one": 1,
                    "someIntegerKey": 123,
                    "someFloatKey": 123.456,
                    "someTrueKey": true,
                    "someFalseKey": false,
                    "someNullKey": .null,
                ],
                "someOtherArrayElement",
            ],
            "someNestedObject": [
                "someOtherKey": "someOtherValue",
            ],
        ]

        #expect(JSONValue(ablyCocoaData: ablyCocoaData) == expected)
    }

    // MARK: Conversion to ably-cocoa data

    @Test(arguments: [
        // object
        (value: ["someKey": "someValue"], expectedResult: ["someKey": "someValue"]),
        // array
        (value: ["someElement"], expectedResult: ["someElement"]),
        // string
        (value: "someString", expectedResult: "someString"),
        // number
        (value: 0, expectedResult: NSNumber(value: 0)),
        (value: 1, expectedResult: NSNumber(value: 1)),
        (value: 123, expectedResult: NSNumber(value: 123)),
        (value: 123.456, expectedResult: NSNumber(value: 123.456)),
        // bool
        (value: true, expectedResult: NSNumber(value: true)),
        (value: false, expectedResult: NSNumber(value: false)),
        // null
        (value: .null, expectedResult: NSNull()),
    ] as[(value: JSONValue, expectedResult: any Sendable)])
    func toAblyCocoaData(value: JSONValue, expectedResult: any Sendable) throws {
        let resultAsNSObject = try #require(value.toAblyCocoaData as? NSObject)
        let expectedResultAsNSObject = try #require(expectedResult as? NSObject)
        #expect(resultAsNSObject == expectedResultAsNSObject)
    }

    // Tests that it creates an object that can be serialized by `JSONSerialization` (which is what ably-cocoa uses for serialization), and that the result of this serialization is what we'd expect.
    @Test
    func toAblyCocoaData_endToEnd() throws {
        let value: JSONValue = [
            "someArray": [
                [
                    "someStringKey": "someString",
                    "zero": 0,
                    "one": 1,
                    "someIntegerKey": 123,
                    "someFloatKey": 123.456,
                    "someTrueKey": true,
                    "someFalseKey": false,
                    "someNullKey": .null,
                ],
                "someOtherArrayElement",
            ],
            "someNestedObject": [
                "someOtherKey": "someOtherValue",
            ],
        ]

        let expectedJSONString = """
        {
          "someArray": [
            {
              "someStringKey": "someString",
              "someIntegerKey": 123,
              "someFloatKey": 123.456,
              "zero": 0,
              "one": 1,
              "someTrueKey": true,
              "someFalseKey": false,
              "someNullKey": null
            },
            "someOtherArrayElement"
          ],
          "someNestedObject": {
            "someOtherKey": "someOtherValue"
          }
        }
        """

        let jsonSerializationOptions: JSONSerialization.WritingOptions = [.sortedKeys]

        let valueData = try JSONSerialization.data(withJSONObject: value.toAblyCocoaData, options: jsonSerializationOptions)
        let expectedData = try {
            let serialized = try JSONSerialization.jsonObject(with: #require(expectedJSONString.data(using: .utf8)))
            return try JSONSerialization.data(withJSONObject: serialized, options: jsonSerializationOptions)
        }()

        #expect(valueData == expectedData)
    }
}
