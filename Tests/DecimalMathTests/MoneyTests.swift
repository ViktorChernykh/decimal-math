@testable import DecimalMath
import Testing

struct MoneyTests {

	// MARK: - Init

	@Test("Init keeps amount if already at correct scale")
	func initKeepsScale() {
		let amount: Decimals = .init(units: 12345, scale: 2) // 123.45
		let money: Money = Money(amount: amount, currency: "USD")
		#expect(money.amount == amount)
		#expect(money.currency == "USD")
	}

	@Test("Init rescales amount if scale mismatch")
	func initRescalesAmount() {
		let amount: Decimals = .init(units: 123, scale: 0) // intended 123.00 RUB
		let money: Money = Money(amount: amount, currency: "RUB")
		#expect(money.amount.scale == 2)
		#expect(money.amount.units == 12300)
	}

	// MARK: - scale(for:)

	@Test("scale(for:) returns known ISO 4217 minor units")
	func scaleForKnownCurrency() {
		#expect(Money.scale(for: "USD") == 2)
		#expect(Money.scale(for: "JPY") == 0)
		#expect(Money.scale(for: "KWD") == 3)
	}

	@Test("scale(for:) returns 2 for unknown currency")
	func scaleForUnknownCurrency() {
		#expect(Money.scale(for: "XYZ") == 2)
	}

	// MARK: - Conversion

	@Test("convert multiplies/divides correctly with integer FX rate")
	func convertWithIntegerRate() {
		let base: Decimals = .init(units: 10000, scale: 2) // 100.00 USD
		let money: Money = Money(amount: base, currency: "USD")

		// rate 2/1 → expect 200 EUR
		let result: Money = money.convert(to: "EUR", numerator: 2, denominator: 1)

		#expect(result.currency == "EUR")
		#expect(result.amount.scale == 2)
		#expect(result.amount.units == 20000)
	}

	@Test("convert applies banker’s rounding on division")
	func convertWithRounding() {
		let base: Decimals = .init(units: 105, scale: 2) // 1.05 USD
		let money: Money = Money(amount: base, currency: "USD")

		// numerator=1, denominator=2 → multiply by 0.5 → 0.525 EUR
		// scaled to 2 decimals with banker’s rounding → 0.52
		let result: Money = money.convert(to: "EUR", numerator: 1, denominator: 2)

		#expect(result.currency == "EUR")
		#expect(result.amount.units == 52)
		#expect(result.amount.scale == 2)
	}

	@Test("convert preserves scale of target currency")
	func convertPreservesTargetScale() {
		let base: Decimals = .init(units: 12345, scale: 2) // 123.45 USD
		let money: Money = Money(amount: base, currency: "USD")

		// Convert to JPY (scale 0). FX rate 1:1
		let result: Money = money.convert(to: "JPY", numerator: 1, denominator: 1)

		#expect(result.currency == "JPY")
		#expect(result.amount.scale == 0)
		// 123.45 → rounded to nearest integer (banker’s rounding) = 123
		#expect(result.amount.units == 123)
	}
}
