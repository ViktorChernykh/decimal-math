import Foundation
import Testing
@testable import DecimalMath

/// Text from outside never stops the process. Each text goes three ways the apps use:
/// a JSON string, `google.type.Decimal` `{"value": ...}` and `Decimals(from: String)`.
@Suite("Decimals from text")
struct DecimalsOutsideDataTextTests {
	private static let corrupted: String = "corrupted at \(OutsideData.pricePath)"

	/// The outcomes of the three ways for one text.
	///
	/// - Parameter text: The text of the number.
	/// - Returns: The outcomes of the JSON string, the `google` form and `Decimals(from:)`.
	private static func outcomes(_ text: String) -> [String] {
		[
			OutsideData.outcome(String(reflecting: text)),
			OutsideData.outcome(#"{"value":\#(String(reflecting: text))}"#),
			OutsideData.describe(Decimals(from: text)),
		]
	}

	@Test("An exponent above 18 is an error", arguments: ["1e19", "1e+19", "1.5e20", "-1e19"])
	func hugeExponentFails(text: String) {
		#expect(Self.outcomes(text) == [Self.corrupted, Self.corrupted, "nil"])
	}

	@Test("A scale above 18 is an error", arguments: [
		"1e-20", "1e-100", "0.0000000000000000001", "1e-9223372036854775807",
	])
	func naturalScaleAbove18Fails(text: String) {
		#expect(Self.outcomes(text) == [Self.corrupted, Self.corrupted, "nil"])
	}

	@Test("Zero always fits", arguments: [
		"0e25", "0.000000000000000000000", "-0e-30", "0e-9223372036854775807",
	])
	func zeroAlwaysFits(text: String) {
		#expect(Self.outcomes(text) == ["value 0 0", "value 0 0", "value 0 0"])
	}

	@Test("Int.min is an error")
	func intMinFails() {
		#expect(Self.outcomes("-9223372036854775808") == [Self.corrupted, Self.corrupted, "nil"])
	}

	@Test("Text ignores the target scale", arguments: [#""1.5""#, #"{"value":"1.5"}"#])
	func targetIgnored(json: String) {
		#expect(OutsideData.outcome(json, scale: 2) == "value 15 1")
	}

	@Test("Values that fit stay the same", arguments: [
		("0.1e19", "value 1000000000000000000 0"),
		("1e18", "value 1000000000000000000 0"),
		("-12.3400", "value -123400 4"),
		("1e-18", "value 1 18"),
		("-9223372036854775807", "value -9223372036854775807 0"),
		(".5", "value 5 1"),
		("0.00", "value 0 2"),
	])
	func fitsAsBefore(text: String, expected: String) {
		#expect(Self.outcomes(text) == [expected, expected, expected])
	}
}
