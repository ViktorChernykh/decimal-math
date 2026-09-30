import Foundation
import Testing
@testable import DecimalMath

/// A JSON number from outside never stops the process and never gives a wrong value.
/// The rules are in ADR bcs-json-parser/0001, p. 2.
@Suite("Decimals from a JSON number")
struct DecimalsOutsideDataNumberTests {
	private static let corrupted: String = "corrupted at \(OutsideData.pricePath)"

	// MARK: - Errors

	@Test("An exponent above 18 is an error", arguments: [
		"1e19", "1e20", "1E20", "1e127", "100000000000000000000", "-1e19",
	], [nil, 2] as [Int?])
	func hugeExponentThrows(json: String, scale: Int?) {
		#expect(OutsideData.outcome(json, scale: scale) == Self.corrupted)
	}

	@Test("An overflow on the way to the target scale is an error", arguments: [
		"1e17", "1e18", "9223372036854775807", "123456789012345678",
	])
	func overflowOnTargetThrows(json: String) {
		#expect(OutsideData.outcome(json, scale: 2) == Self.corrupted)
	}

	@Test("A shift to the target scale above 18 is an error", arguments: ["1e-21", "1e-30"])
	func shiftAbove18Throws(json: String) {
		#expect(OutsideData.outcome(json, scale: 2) == Self.corrupted)
	}

	@Test("A mantissa above Int.max is an error even when the result would fit", arguments: [
		("18446744073709551616", nil),
		("18446744073709551616", 2),
		("99999999999999999999", nil),
		("99999999999999999999", 2),
		("0.1234567890123456789012345", nil),
		("0.1234567890123456789012345", 2),
		("0.1234567890123456789012", 8),
		("99e17", -1),
	] as [(String, Int?)])
	func mantissaAboveIntMaxThrows(json: String, scale: Int?) {
		#expect(OutsideData.outcome(json, scale: scale) == Self.corrupted)
	}

	@Test("A value that was silently wrong on Darwin is an error", arguments: [
		("9223372036854775808", nil),
		("18446744073709551615", nil),
		("18446744073709551615", 2),
		("12345678901234567891", nil),
		("99e17", nil),
		("-9223372036854775809", nil),
		("12345678901234567890000", nil),
		("92233720368547758.08", 2),
	] as [(String, Int?)])
	func silentWrongValuesThrow(json: String, scale: Int?) {
		#expect(OutsideData.outcome(json, scale: scale) == Self.corrupted)
	}

	@Test("Int.min is an error", arguments: [nil, 2] as [Int?])
	func intMinThrows(scale: Int?) {
		#expect(OutsideData.outcome("-9223372036854775808", scale: scale) == Self.corrupted)
	}

	@Test("Without a target scale, a scale above 18 is an error", arguments: [
		"1e-19", "1e-30", "0.1234567890123456789",
	])
	func naturalScaleAbove18Throws(json: String) {
		#expect(OutsideData.outcome(json) == Self.corrupted)
	}

	/// 1e-5 at 19 needs a shift of 14 only, so only the range check of the target catches it.
	@Test("A target scale outside -18...18 is an error", arguments: [
		("1e-5", 19),
		("1", 19),
		("1", -19),
	])
	func targetOutOfRangeThrows(json: String, scale: Int) {
		#expect(OutsideData.outcome(json, scale: scale) == Self.corrupted)
	}

	/// Zero skips the shift check, so only the range check of the target catches these.
	@Test("A target scale outside -18...18 is an error for zero too", arguments: [
		("0", 19),
		("0", -19),
		("0.00", 19),
	])
	func zeroTargetOutOfRangeThrows(json: String, scale: Int) {
		#expect(OutsideData.outcome(json, scale: scale) == Self.corrupted)
	}

	// MARK: - Zero

	@Test("Zero always fits", arguments: [
		("0e25", nil, "value 0 0"),
		("0e25", 2, "value 0 2"),
		("0e-30", 8, "value 0 8"),
		("0e-25", nil, "value 0 0"),
	] as [(String, Int?, String)])
	func zeroAlwaysFits(json: String, scale: Int?, expected: String) {
		#expect(OutsideData.outcome(json, scale: scale) == expected)
	}

	// MARK: - Guards: values that fit keep what 0.10.8 gave

	@Test("Values that fit stay the same", arguments: [
		("-9223372036854775807", nil, "value -9223372036854775807 0"),
		("9223372036854775807", nil, "value 9223372036854775807 0"),
		("123456789012345678", nil, "value 123456789012345678 0"),
		("1234567890123456789", nil, "value 1234567890123456789 0"),
		("1e18", nil, "value 1000000000000000000 0"),
		("1e17", nil, "value 100000000000000000 0"),
		("1e-18", nil, "value 1 18"),
		("1e-20", 8, "value 0 8"),
		("12345", -2, "value 123 -2"),
		("1e18", -1, "value 100000000000000000 -1"),
		("5.120", nil, "value 512 2"),
		("0", -5, "value 0 -5"),
		("1", 18, "value 1000000000000000000 18"),
		("1e18", -18, "value 1 -18"),
		("1.5", 2, "value 150 2"),
	] as [(String, Int?, String)])
	func fitsAsBefore(json: String, scale: Int?, expected: String) {
		#expect(OutsideData.outcome(json, scale: scale) == expected)
	}

	/// Zero with a natural scale 1...18 differs by platform (ADR "Не входит", p. 6).
	@Test("Zero with fraction digits keeps the scale of the platform")
	func zeroWithFractionDigits() {
#if os(Linux)
		#expect(OutsideData.outcome("0.00") == "value 0 0")
#else
		#expect(OutsideData.outcome("0.00") == "value 0 2")
#endif
	}

	@Test("The target scale rounds half to even", arguments: [
		("1.235", "value 124 2"),
		("1.225", "value 122 2"),
		("-1.235", "value -124 2"),
	])
	func halfToEven(json: String, expected: String) {
		#expect(OutsideData.outcome(json, scale: 2) == expected)
	}

	/// Foundation rejects such a number before our code, zero too (ADR p. 2).
	@Test("A number outside the range of Decimal is an error with the path", arguments: [
		"1e300", "1e128", "0e200", "0e-129",
	])
	func outOfDecimalRange(json: String) {
		#expect(OutsideData.outcome(json) == Self.corrupted)
	}
}
