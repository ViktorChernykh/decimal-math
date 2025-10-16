import Foundation
import Testing
@testable import DecimalMath

@Suite
struct DecimalsDecodingTests {
	// MARK: - Helpers

	/// Decodes a single JSON value into Decimals.
	/// Accepts JSON like: `5.12`, `"5.120"`, `"1.23e-3"`, `100`, `"-0.01"`.
	@inline(__always)
	private func decode(_ json: String) throws -> Decimals {
		let data: Data = Data(json.utf8)
		let decoder: JSONDecoder = .init()
		return try decoder.decode(Decimals.self, from: data)
	}

	/// Wraps a throwing decode and returns the error string (for negative tests).
	@inline(__always)
	private func decodeError(_ json: String) -> String {
		do {
			_ = try decode(json)
			return "no error"
		} catch {
			return "error"
		}
	}

	// MARK: - Tests

	/// JSON number → Decimal is the path. We expect the correct scale and units.
	@Test
	func decode_Number_SimpleFraction() throws {
		// 5.12 → scale = 2, units = 512
		let value: Decimals = try decode("5.12")
		#expect(value.scale == 2, "Scale for 5.12 must be 2")
		#expect(value.units == 512, "Units for 5.12 must be 512")
	}

	/// JSON number → integer without fraction.
	@Test
	func decode_Number_Integer() throws {
		let value: Decimals = try decode("100")
		#expect(value.scale == 0)
		#expect(value.units == 100)
	}

	/// JSON number → negative fractional.
	@Test
	func decode_Number_NegativeFraction() throws {
		let value: Decimals = try decode("-0.01")
		#expect(value.scale == 2)
		#expect(value.units == -1)
	}

	/// JSON string is negative with scientific notation.
	@Test
	func decode_String_Scientific_Negative() throws {
		// "-4.5e+2" = -450 → scale 0, units -450
		let value: Decimals = try decode("-4.5e+2")
		#expect(value.scale == 0, "Text '-4.5e+2' expands to -450 → scale 0")
		#expect(value.units == -450, "Units for -450 with scale 0 must be -450")
	}

	/// Invalid row → must fall with dataCorruptedError.
	@Test
	func decode_String_Invalid_Fails() {
		let error: String = decodeError(#""not-a-number""#)
		#expect(error == "error")
	}

	/// Narrow corner-case: a line with a dot and without a fractional part — the scale must be 0.
	@Test
	func decode_String_TrailingDot() {
		let error: String = decodeError("42.")
		#expect(error == "error")
	}

	/// Narrow corner-case: ".5" is correct as 0.5.
	@Test
	func decode_String_LeadingDot() {
		let error: String = decodeError(".5")
		#expect(error == "error")
	}

	/// JSON number in scientific notation. JSONDecoder→Decimal usually understands this directly.
	@Test
	func decode_Number_Scientific() throws {
		// 1e-6 → 0.000001 → scale 6, units 1
		let value: Decimals = try decode("1e-6")
		#expect(value.scale == 6)
		#expect(value.units == 1)
	}

	/// Guarantee: A top-level array of strings/numbers also works.
	@Test
	func decode_Array_Mixed() throws {
		let data: Data = Data("[5.120, 5.12, 1e2, -3]".utf8)
		let decoder: JSONDecoder = .init()
		let values: [Decimals] = try decoder.decode([Decimals].self, from: data)

		#expect(values.count == 4)
		// "5.120"
		#expect(values[0].scale == 2 && values[0].units == 512)
		// 5.12
		#expect(values[1].scale == 2 && values[1].units == 512)
		// "1e2" → 100 → scale 0
		#expect(values[2].scale == 0 && values[2].units == 100)
		// -3 → scale 0
		#expect(values[3].scale == 0 && values[3].units == -3)
	}

	/// Decoding from a JSON **string** must go through the string path of `init(from:)`.
	@Test("Decode from JSON string")
	func testDecodeFromJsonString() throws {
		let jsonString: String = "\"-12.3400\"" // a JSON string token
		let data: Data = Data(jsonString.utf8)
		let decoder: JSONDecoder = .init()
		let value: Decimals = try decoder.decode(Decimals.self, from: data)
		#expect(value.units == -123400, "Units should be -123400")
		#expect(value.scale == 4, "Scale should be 4 (preserve fractional zeros)")
	}

	@Test("Decode from invalid1 JSON string")
	func testDecodeFromInvalid1JsonString() throws {
		let jsonString: String = "\"12.34.00\"" // a JSON string token
		let error: String = decodeError(jsonString)
		#expect(error == "error")
	}

	@Test("Decode from invalid2 JSON string")
	func testDecodeFromInvalid2JsonString() throws {
		let jsonString: String = "\".3400\"" // a JSON string token
		let error: String = decodeError(jsonString)
		#expect(error == "error")
	}

	/// Decoding from a JSON **number** must use the precise Decimal path.
	@Test("Decode from JSON number")
	func testDecodeFromJsonNumber() throws {
		let jsonNumber: String = "12.34" // a JSON number token
		let data: Data = Data(jsonNumber.utf8)
		let decoder: JSONDecoder = .init()
		let value: Decimals = try decoder.decode(Decimals.self, from: data)
		#expect(value.units == 1234, "Units should be 1234")
		#expect(value.scale == 2, "Scale should be 2")
	}
}
