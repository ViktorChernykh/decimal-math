#if !os(Linux)
import Foundation
import Testing
@testable import DecimalMath

/// On Linux `init?(decimal:scale:)` reads `Decimal.description`, on Darwin the storage fields.
/// Both ways must give the same result. `textParts(of:)` is the Linux way, built on macOS too.
@Suite("Decimals: the Linux way gives what Darwin gives")
struct DecimalsLinuxBranchTests {
	private static let texts: [String] = [
		"0", "5.12", "-7.50", "1200", "1e18", "1e19", "1e20", "1e-18", "1e-19", "1e-20", "1e-30",
		"9223372036854775807", "-9223372036854775807", "9223372036854775808",
		"-9223372036854775808", "18446744073709551615", "18446744073709551616",
		"99999999999999999999", "99e17", "12345678901234567890000", "92233720368547758.08",
		"0.1234567890123456789012345", "0.1234567890123456789012", "1.235", "-1.225", "12345",
		"0e25", "0e-25", "0e-30",
	]

	/// Describes the result of one way.
	///
	/// - Parameters:
	///   - parts: The mantissa and the natural scale, or `nil`.
	///   - target: The target scale, or `nil`.
	/// - Returns: "value <units> <scale>" or "nil".
	private static func result(
		_ parts: (mantissa: Int, scale: Int)?,
		target: Int?
	) -> String {
		guard let parts else {
			return "nil"
		}
		let value: Decimals? = Decimals.fitted(
			mantissa: parts.mantissa,
			naturalScale: parts.scale,
			targetScale: target
		)
		return OutsideData.describe(value)
	}

	@Test("Both ways agree", arguments: texts, [nil, 2, 8, -1, 19] as [Int?])
	func bothWaysAgree(text: String, target: Int?) throws {
		let decimal: Decimal = try #require(Decimal(string: text))
		let darwin: String = Self.result(Decimals.storedParts(of: decimal), target: target)
		let linux: String = Self.result(Decimals.textParts(of: decimal), target: target)

		#expect(darwin == linux)
	}

	/// The one known difference (ADR, "Не входит", p. 6): zero with a natural scale 1...18.
	@Test("Zero with a natural scale 1...18 differs without a target")
	func zeroWithNaturalScaleDiffers() throws {
		let decimal: Decimal = try #require(Decimal(string: "0e-5"))

		#expect(Self.result(Decimals.storedParts(of: decimal), target: nil) == "value 0 5")
		#expect(Self.result(Decimals.textParts(of: decimal), target: nil) == "value 0 0")
	}

	@Test("NaN gives nil both ways")
	func nanGivesNil() {
		#expect(Decimals.storedParts(of: .nan) == nil)
		#expect(Decimals.textParts(of: .nan) == nil)
	}
}
#endif
