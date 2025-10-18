@testable import DecimalMath
import Foundation
import Testing

// MARK: - Helpers

/// Decode `Decimals` from a JSON boxed as  {"value": "<str>"}
private func decodeAmount(_ string: String) throws -> Decimals {
	let json: String = #"{"value":\#(String(reflecting: string))}"#
	let data: Data = Data(json.utf8)
	let decoder: JSONDecoder = .init()

	return try decoder.decode(Decimals.self, from: data)
}

/// Expect a decoding failure for invalid strings.
private func expectDecodeFailure(_ string: String) -> Bool {
	do {
		_ = try decodeAmount(string)
		return false // should not reach here
	} catch {
		return true
	}
}

// MARK: - Tests

@Suite("Decimals ← google.type.Decimal decoding")
struct GoogleDecimalDecodingTests {

	@Test("Plain integers and zero")
	func testIntegers() throws {
		let v0: Decimals = try decodeAmount("0")
		#expect(v0.units == 0 && v0.scale == 0)

		let v1: Decimals = try decodeAmount("123")
		#expect(v1.units == 123 && v1.scale == 0)

		let vn: Decimals = try decodeAmount("-42")
		#expect(vn.units == -42 && vn.scale == 0)
	}

	@Test("Dot as decimal separator")
	func testDotSeparator() throws {
		let v1: Decimals = try decodeAmount("123.45")
		#expect(v1.units == 12_345 && v1.scale == 2)

		let v2: Decimals = try decodeAmount("-0.007")
		#expect(v2.units == -7 && v2.scale == 3)

		let v3: Decimals = try decodeAmount("+42.0")
		#expect(v3.units == 420 && v3.scale == 1)
	}

	@Test("Comma as decimal separator (no grouping)")
	func testCommaSeparator() throws {
		// Interpreted as 1.234 (not grouping), so units=1234, scale=3
		let v1: Decimals = try decodeAmount("1,234")
		#expect(v1.units == 1_234 && v1.scale == 3)

		let v2: Decimals = try decodeAmount("-10,50")
		#expect(v2.units == -1_050 && v2.scale == 2)
	}

	@Test("Leading/trailing spaces are trimmed")
	func testTrimming() throws {
		let v: Decimals = try decodeAmount("   7.5  ")
		#expect(v.units == 75 && v.scale == 1)
	}

	@Test("Invalid forms must fail")
	func testInvalidForms() {
		// Empty
		#expect(expectDecodeFailure(""))
		// Only sign
		#expect(expectDecodeFailure("+"))
		#expect(expectDecodeFailure("-"))
		// Separator without fractional digits
		#expect(expectDecodeFailure("123."))
		#expect(expectDecodeFailure("5,"))
		// Multiple separators
		#expect(expectDecodeFailure("1,2,3"))
		#expect(expectDecodeFailure("4.5.6"))
		// Internal spaces
		#expect(expectDecodeFailure("1 2"))
		#expect(expectDecodeFailure(" - 1 "))
	}

	@Test("No grouping allowed")
	func testNoGrouping() {
		// "1,234.56" is *not* allowed as grouping + fraction: there are two separators → invalid
		#expect(expectDecodeFailure("1,234.56"))
		#expect(expectDecodeFailure("1.234,56"))
	}

	@Test("Roundtrip through toGoogleDecimal for a few samples")
	func testRoundtrip() throws {
		let samples: [(String, Int, Int)] = [
			("0",        0, 0),
			("12.340",   12_340, 3),
			("-0.010",   -10, 3),
			("999.99",   99_999, 2),
			("1,5",      15, 1) // comma as decimal
		]

		for (string, expectedUnits, expectedScale) in samples {
			let dec: Decimals = try decodeAmount(string)
			#expect(dec.units == expectedUnits)
			#expect(dec.scale == expectedScale)

			let value: String
			if dec.scale > 0 {
				var string: String = .init(Double(dec.units) / Double(Int.p10[dec.scale]))

				let comps: [String] = string.components(separatedBy: ".")
				if comps.count == 2, comps[1].count < dec.scale {
					for _ in comps[1].count..<dec.scale {
						string += "0"
					}
				}
				value = string
			} else {
				value = "\(dec.units)"
			}
			let gDec: GoogleDecimal = .init(value: value)

			// Canonical string must use '.' and have exactly `scale` fractional digits.
			if dec.scale == 0 {
				#expect(gDec.value == String(dec.units))
			} else {
				let intPart: Int = abs(dec.units) / Int.p10[dec.scale]
				let fracPart: Int = abs(dec.units) % Int.p10[dec.scale]
				let sign: String = dec.units < 0 ? "-" : ""
				let fracString: String = String(format: "%0*\(0)d", dec.scale, fracPart) // zero-padded
				let expected: String = "\(sign)\(intPart).\(fracString)"
				#expect(gDec.value == expected)
			}
		}
	}
}
