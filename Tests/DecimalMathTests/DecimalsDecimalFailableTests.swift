import Foundation
import Testing
@testable import DecimalMath

/// `init?(decimal:scale:)` gives `nil` instead of stopping the process or giving a wrong value.
/// Trader-backend (Postgres) and the price fields of the terminal call it directly.
@Suite("Decimals from Decimal")
struct DecimalsDecimalFailableTests {
	/// Converts the text to `Decimal` and then to `Decimals`, and describes the result.
	///
	/// - Parameters:
	///   - text: The text of the `Decimal`.
	///   - scale: The target scale, or `nil`.
	/// - Returns: "value <units> <scale>" or "nil".
	/// - Throws: When `Decimal(string:)` cannot read the text.
	private static func convert(_ text: String, scale: Int?) throws -> String {
		let decimal: Decimal = try #require(Decimal(string: text))

		return OutsideData.describe(Decimals(decimal: decimal, scale: scale))
	}

	@Test("A value that does not fit gives nil", arguments: [
		("1e19", nil), ("1e20", nil), ("18446744073709551616", nil),
		("99999999999999999999", nil), ("-9223372036854775808", nil),
		("9223372036854775808", nil), ("18446744073709551615", nil), ("99e17", nil),
		("-9223372036854775809", nil), ("12345678901234567890000", nil),
		("0.1234567890123456789012345", nil),
		("92233720368547758.08", 2), ("1e17", 2), ("1e-30", 2),
		("0.1234567890123456789012", 8), ("99e17", -1),
	] as [(String, Int?)])
	func nilWhenNotFits(text: String, scale: Int?) throws {
		#expect(try Self.convert(text, scale: scale) == "nil")
	}

	@Test("NaN gives nil", arguments: [nil, 2] as [Int?])
	func nilForNaN(scale: Int?) {
		#expect(OutsideData.describe(Decimals(decimal: .nan, scale: scale)) == "nil")
	}

	@Test("Without a target scale, a scale above 18 gives nil", arguments: [
		"1e-19", "0.1234567890123456789",
	])
	func nilWithoutTargetAbove18(text: String) throws {
		#expect(try Self.convert(text, scale: nil) == "nil")
	}

	@Test("A target scale outside -18...18 gives nil", arguments: [
		("1e-5", 19), ("1", -19), ("0", 19), ("0", -19),
	])
	func nilForTargetOutOfRange(text: String, scale: Int) throws {
		#expect(try Self.convert(text, scale: scale) == "nil")
	}

	@Test("Zero always fits", arguments: [
		("0e25", -5, "value 0 -5"),
		("0e-30", 8, "value 0 8"),
		("0e25", nil, "value 0 0"),
		("0e-25", nil, "value 0 0"),
	] as [(String, Int?, String)])
	func zeroAlwaysFits(text: String, scale: Int?, expected: String) throws {
		#expect(try Self.convert(text, scale: scale) == expected)
	}

	@Test("Values that fit stay the same", arguments: [
		("1e-18", nil, "value 1 18"),
		("1e18", -1, "value 100000000000000000 -1"),
		("12345", -2, "value 123 -2"),
		("-9223372036854775807", nil, "value -9223372036854775807 0"),
		("1e-20", 8, "value 0 8"),
		("1", 18, "value 1000000000000000000 18"),
		("1e18", -18, "value 1 -18"),
	] as [(String, Int?, String)])
	func fitsAsBefore(text: String, scale: Int?, expected: String) throws {
		#expect(try Self.convert(text, scale: scale) == expected)
	}
}
