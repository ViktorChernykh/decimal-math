import Foundation
import Testing
@testable import DecimalMath

struct DecimalsDecimalInitTests {

	@Test
	func initFromDecimal_usesNaturalScale_simpleFraction() throws {
		// 5.12 → (512, 2)
		let decimal: Decimal = Decimal(string: "5.12")!
		let value: Decimals = try #require(Decimals(decimal: decimal))

		#expect(value.units == 512)
		#expect(value.scale == 2)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_usesNaturalScale_integerWithPositiveExponent() throws {
		// Construct Decimal with mantissa=12, exponent=2 → 12 * 10^2 = 1200
		let decimal: Decimal = Decimal(string: "1200")!

		let value: Decimals = try #require(Decimals(decimal: decimal))

		// Natural scale is 0, full mantissa is 1200
		#expect(value.scale == 0)
		#expect(value.units == 1200)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_usesScale_integerWithPositiveExponent() throws {
		// Construct Decimal with mantissa=12, exponent=2 → 12 * 10^2 = 1200
		let decimal: Decimal = Decimal(string: "1200")!

		let value: Decimals = try #require(Decimals(decimal: decimal, scale: 2))

		// Natural scale is 0, full mantissa is 1200
		#expect(value.scale == 2)
		#expect(value.units == 120000)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_preservesSign() throws {
		// -7.50 → (-750, 2)
		let decimal: Decimal = Decimal(string: "-7.50")!
		let value: Decimals = try #require(Decimals(decimal: decimal))

		#expect(value.scale == 1)
		#expect(value.units == -75)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_withTargetScale_higherThanNatural() throws {
		// 5.12 → natural: (512, 2)
		// targetScale = 4 → (51200, 4), numeric value must stay 5.12
		let decimal: Decimal = Decimal(string: "5.12")!
		let value: Decimals = try #require(Decimals(decimal: decimal, scale: 4))

		#expect(value.scale == 4)
		#expect(value.units == 51200)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_withTargetScale_equalToNatural() throws {
		// targetScale == naturalScale → no rescale
		let decimal: Decimal = Decimal(string: "123.45")!
		let value: Decimals = try #require(Decimals(decimal: decimal, scale: 2))

		#expect(value.scale == 2)
		#expect(value.units == 12345)
		#expect(value.decimal == decimal)
	}

	@Test(
		"Conversion supports Int-backed Decimal boundaries",
		arguments: [
			("0", 0, 0),
			("0.000000000000000001", 1, 18),
			("9223372036854775807", Int.max, 0),
		]
	)
	func initFromDecimal_supportsIntBackedBoundaries(
		_ source: String,
		expectedUnits: Int,
		expectedScale: Int
	) throws {
		let decimal: Decimal = try #require(Decimal(string: source))
		let value: Decimals = try #require(Decimals(decimal: decimal))

		#expect(value.units == expectedUnits)
		#expect(value.scale == expectedScale)
		#expect(value.decimal == decimal)
	}

	@Test(
		"Target scale applies banker's rounding",
		arguments: [
			("5.125", 512),
			("5.135", 514),
			("-5.125", -512),
			("-5.135", -514),
		]
	)
	func initFromDecimal_downscalesWithBankersRounding(_ source: String, expectedUnits: Int) throws {
		let decimal: Decimal = try #require(Decimal(string: source))
		let value: Decimals = try #require(Decimals(decimal: decimal, scale: 2))

		#expect(value.units == expectedUnits)
		#expect(value.scale == 2)
	}
}
