import Foundation
import Testing
@testable import DecimalMath

/// The object form `{"units": ..., "scale": ...}` from outside never stops the process later.
@Suite("Decimals from the object form")
struct DecimalsOutsideDataObjectTests {
	private static let unitsPath: String = "corrupted at \(OutsideData.pricePath).units"
	private static let scalePath: String = "corrupted at \(OutsideData.pricePath).scale"

	/// Makes the JSON text of the object form.
	///
	/// - Parameters:
	///   - units: The units field.
	///   - scale: The scale field.
	/// - Returns: The JSON text.
	private static func object(_ units: Int, _ scale: Int) -> String {
		#"{"units":\#(units),"scale":\#(scale)}"#
	}

	@Test("A scale outside -18...18 is an error, for zero too", arguments: [
		(1, 19), (1, -19), (1, 200), (0, 19), (0, -19),
	])
	func scaleOutOfRangeThrows(units: Int, scale: Int) {
		#expect(OutsideData.outcome(Self.object(units, scale)) == Self.scalePath)
	}

	@Test("Int.min is an error")
	func intMinThrows() {
		#expect(OutsideData.outcome(Self.object(.min, 0)) == Self.unitsPath)
	}

	/// `description` writes units * 10^|scale| as `Int`, so the product must fit.
	@Test("With a negative scale, units * 10^|scale| must fit into Int", arguments: [
		(10, -18), (-10, -18), (1000, -17),
	])
	func negativeScaleOverflowThrows(units: Int, scale: Int) {
		#expect(OutsideData.outcome(Self.object(units, scale)) == Self.unitsPath)
	}

	@Test("A bad units field is an error with its path", arguments: [
		#"{"units":1e20,"scale":0}"#,
		#"{"units":99999999999999999999,"scale":0}"#,
		#"{"units":1.5,"scale":0}"#,
		#"{"units":"x","scale":0}"#,
	])
	func badUnitsHasPath(json: String) {
		#expect(OutsideData.outcome(json) == Self.unitsPath)
	}

	@Test("A bad scale field is an error with its path", arguments: [
		#"{"units":1,"scale":2.5}"#,
		#"{"units":1,"scale":1e20}"#,
	])
	func badScaleHasPath(json: String) {
		#expect(OutsideData.outcome(json) == Self.scalePath)
	}

	@Test("A missing key stays keyNotFound", arguments: [
		(#"{"units":1}"#, "key not found scale"),
		("{}", "key not found units"),
		(#"{"value":5}"#, "key not found units"),
	])
	func keyNotFoundKept(json: String, expected: String) {
		#expect(OutsideData.outcome(json) == expected)
	}

	@Test("Values that fit stay the same", arguments: [
		(1, -18), (1, -1), (1, 0), (1, 18), (9, -18), (-9, -18), (0, -18),
		(Int.max, 0), (-Int.max, 18),
	])
	func fitsAsBefore(units: Int, scale: Int) {
		#expect(OutsideData.outcome(Self.object(units, scale)) == "value \(units) \(scale)")
	}

	@Test("The object ignores the target scale")
	func targetIgnored() {
		#expect(OutsideData.outcome(Self.object(15, 1), scale: 2) == "value 15 1")
	}

	@Test("encode then decode gives the same value", arguments: [
		(Int.max, 18), (-Int.max, 0), (9, -18), (0, 0),
	])
	func roundTrip(units: Int, scale: Int) throws {
		let data: Data = try JSONEncoder().encode(Decimals(units: units, scale: scale))
		let json: String = String(decoding: data, as: UTF8.self)

		#expect(OutsideData.outcome(json) == "value \(units) \(scale)")
	}
}
