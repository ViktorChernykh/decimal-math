@testable import DecimalMath
import Testing

struct QuantityMathExitTests {

	// MARK: - roundToLot preconditions

	@Test("roundToLot: lotSize must be > 0")
	func roundToLot_invalidLot_exits() async {
		await #expect(processExitsWith: .failure) {
			let q: Decimals = .init(units: 100, scale: 0)
			_ = QuantityMath.roundToLot(q, lotSize: 0, mode: .floor)
		}
	}

	// MARK: - roundToTick preconditions

	@Test("roundToTick: tick must be > 0")
	func roundToTick_invalidTick_exits() async {
		await #expect(processExitsWith: .failure) {
			let p: Decimals = .init(units: 1_000, scale: 2)
			_ = QuantityMath.roundToTick(p, tick: 0, mode: .nearest)
		}
	}

	// MARK: - clamp preconditions

	@Test("clamp: scales must match")
	func clamp_scaleMismatch_exits() async {
		await #expect(processExitsWith: .failure) {
			let q: Decimals = .init(units: 100, scale: 0)
			let lo: Decimals = .init(units: 0, scale: 1)
			let hi: Decimals = .init(units: 100, scale: 1)

			_ = QuantityMath.clamp(q, min: lo, max: hi)
		}
	}

	@Test("clamp: min must be <= max")
	func clamp_invalidBounds_exits() async {
		await #expect(processExitsWith: .failure) {
			let q: Decimals = .init(units: 50, scale: 0)
			let lo: Decimals = .init(units: 100, scale: 0)
			let hi: Decimals = .init(units: 90, scale: 0)

			_ = QuantityMath.clamp(q, min: lo, max: hi)
		}
	}

	// MARK: - vwap preconditions

	@Test("vwap: non-empty fills")
	func vwap_empty_exits() async {
		await #expect(processExitsWith: .failure) {
			_ = QuantityMath.vwap(fills: [])
		}
	}

	@Test("vwap: price scales must match")
	func vwap_priceScaleMismatch_exits() async {
		await #expect(processExitsWith: .failure) {
			let f1: (Decimals, Decimals) = (.init(units: 10_000, scale: 3), .init(units: 10_000, scale: 2))
			let f2: (Decimals, Decimals) = (.init(units: 10_000, scale: 3), .init(units: 10_000, scale: 3)) // price scale=3 (mismatch)

			_ = QuantityMath.vwap(fills: [f1, f2])
		}
	}

	@Test("vwap: total quantity must not be zero")
	func vwap_zeroQty_exits() async {
		await #expect(processExitsWith: .failure) {
			let f1: (Decimals, Decimals) = (.init(units: 10_000, scale: 3), .init(units: 10_000, scale: 2))
			let f2: (Decimals, Decimals) = (.init(units: -10_000, scale: 3), .init(units: 10_000, scale: 2))

			_ = QuantityMath.vwap(fills: [f1, f2]) // quantities sum to zero
		}
	}

	// MARK: - maxBuyQuantity preconditions

	@Test("maxBuyQuantity: budget must be non-negative")
	func maxBuyQuantity_negativeBudget_exits() async {
		await #expect(processExitsWith: .failure) {
			let budget: Decimals = .init(units: -1, scale: 2)
			let price: Decimals = .init(units: 100, scale: 2)

			_ = QuantityMath.maxBuyQuantity(
				budget: budget,
				unitPrice: price,
				quantityScale: 0,
				lotSize: 1,
				feeBps: 0
			)
		}
	}

	@Test("maxBuyQuantity: unitPrice must be positive")
	func maxBuyQuantity_nonPositivePrice_exits() async {
		await #expect(processExitsWith: .failure) {
			let budget: Decimals = .init(units: 100, scale: 2)
			let price: Decimals = .init(units: 0, scale: 2)

			_ = QuantityMath.maxBuyQuantity(
				budget: budget,
				unitPrice: price,
				quantityScale: 0,
				lotSize: 1,
				feeBps: 0
			)
		}
	}

	@Test("maxBuyQuantity: lotSize must be > 0")
	func maxBuyQuantity_invalidLot_exits() async {
		await #expect(processExitsWith: .failure) {
			let budget: Decimals = .init(units: 100, scale: 2)
			let price: Decimals = .init(units: 10, scale: 2)

			_ = QuantityMath.maxBuyQuantity(
				budget: budget,
				unitPrice: price,
				quantityScale: 0,
				lotSize: 0,
				feeBps: 0
			)
		}
	}
}
