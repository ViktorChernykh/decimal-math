import Foundation
import Testing
@testable import DecimalMath

struct DecimalsDecimalInitTests {

	@Test
	func initFromDecimal_usesNaturalScale_simpleFraction() {
		// 5.12 → (512, 2)
		let decimal: Decimal = Decimal(string: "5.12")!
		let value: Decimals = .init(decimal: decimal)

		#expect(value.units == 512)
		#expect(value.scale == 2)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_usesNaturalScale_integerWithPositiveExponent() {
		// Construct Decimal with mantissa=12, exponent=2 → 12 * 10^2 = 1200
		let decimal: Decimal = Decimal(string: "1200")!

		let value: Decimals = .init(decimal: decimal)

		// Natural scale is 0, full mantissa is 1200
		#expect(value.scale == 0)
		#expect(value.units == 1200)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_usesScale_integerWithPositiveExponent() {
		// Construct Decimal with mantissa=12, exponent=2 → 12 * 10^2 = 1200
		let decimal: Decimal = Decimal(string: "1200")!

		let value: Decimals = .init(decimal: decimal, scale: 2)

		// Natural scale is 0, full mantissa is 1200
		#expect(value.scale == 2)
		#expect(value.units == 120000)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_preservesSign() {
		// -7.50 → (-750, 2)
		let decimal: Decimal = Decimal(string: "-7.50")!
		let value: Decimals = .init(decimal: decimal)

		#expect(value.scale == 1)
		#expect(value.units == -75)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_withTargetScale_higherThanNatural() {
		// 5.12 → natural: (512, 2)
		// targetScale = 4 → (51200, 4), numeric value must stay 5.12
		let decimal: Decimal = Decimal(string: "5.12")!
		let value: Decimals = .init(decimal: decimal, scale: 4)

		#expect(value.scale == 4)
		#expect(value.units == 51200)
		#expect(value.decimal == decimal)
	}

	@Test
	func initFromDecimal_withTargetScale_equalToNatural() {
		// targetScale == naturalScale → no rescale
		let decimal: Decimal = Decimal(string: "123.45")!
		let value: Decimals = .init(decimal: decimal, scale: 3)

		#expect(value.scale == 3)
		#expect(value.units == 123450)
		#expect(value.decimal == decimal)
	}
}
