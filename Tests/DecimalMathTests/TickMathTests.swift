@testable import DecimalMath
import Testing

struct TickMathTests {

	// MARK: - On-grid behavior

	@Test("roundPrice: on-grid price stays unchanged for all modes")
	func onGrid_stays() {
		// 123.45 with scale=2 is on grid for tick=0.05 (5 minor units).
		let price: Decimals = .init(units: 12_345, scale: 2)
		let tick: Int = 5

		#expect(TickMath.roundPrice(price, tick: tick, mode: .floor).units == 12_345)
		#expect(TickMath.roundPrice(price, tick: tick, mode: .ceil).units  == 12_345)
		#expect(TickMath.roundPrice(price, tick: tick, mode: .nearest).units == 12_345)
	}

	// MARK: - Off-grid positive prices

	@Test("roundPrice: floor/ceil/nearest on off-grid positive price")
	func offGrid_positive() {
		// 123.43 off-grid for tick=0.05 (remainder 3)
		let price: Decimals = .init(units: 12_343, scale: 2)
		let tick: Int = 5

		let floored: Decimals = TickMath.roundPrice(price, tick: tick, mode: .floor)    // 123.40
		let ceiled:  Decimals = TickMath.roundPrice(price, tick: tick, mode: .ceil)     // 123.45
		let nearest: Decimals = TickMath.roundPrice(price, tick: tick, mode: .nearest)  // 123.45 (3 > half(2))

		#expect(floored.units == 12_340)
		#expect(ceiled.units  == 12_345)
		#expect(nearest.units == 12_345)
	}

	// MARK: - Off-grid negative prices

	@Test("roundPrice: floor/ceil/nearest on off-grid negative price")
	func offGrid_negative() {
		// -123.43 off-grid for tick=0.05 (remainder -3)
		let price: Decimals = .init(units: -12_343, scale: 2)
		let tick: Int = 5

		let floored: Decimals = TickMath.roundPrice(price, tick: tick, mode: .floor)    // toward -∞ → -123.45
		let ceiled:  Decimals = TickMath.roundPrice(price, tick: tick, mode: .ceil)     // toward +∞ → -123.40
		let nearest: Decimals = TickMath.roundPrice(price, tick: tick, mode: .nearest)  // |rem|=3>2 → -123.45

		#expect(floored.units == -12_345)
		#expect(ceiled.units  == -12_340)
		#expect(nearest.units == -12_345)
	}

	// MARK: - Half-to-even ties (only meaningful for even tick)

	@Test("roundPrice: nearest uses half-to-even when remainder is exactly half the tick (even tick)")
	func nearest_halfToEven() {
		// tick = 0.10 (10 minor units). Half = 5.
		// Even quotient: 1.25 → 125; div=12 (even), rem=5 → stay at 1.20 (120).
		let pEven: Decimals = .init(units: 125, scale: 2)
		let rEven: Decimals = TickMath.roundPrice(pEven, tick: 10, mode: .nearest)
		#expect(rEven.units == 120)

		// Odd quotient: 1.15 → 115; div=11 (odd), rem=5 → move to even boundary 1.20 (120).
		let pOdd: Decimals = .init(units: 115, scale: 2)
		let rOdd: Decimals = TickMath.roundPrice(pOdd, tick: 10, mode: .nearest)
		#expect(rOdd.units == 120)

		// Negative tie: -1.25 → div = -12 (even), rem = -5 → stay at -1.20 ( -120 )
		let pNeg: Decimals = .init(units: -125, scale: 2)
		let rNeg: Decimals = TickMath.roundPrice(pNeg, tick: 10, mode: .nearest)
		#expect(rNeg.units == -120)
	}

	@Test("roundPrice: tick must be > 0 (precondition)")
	func tick_mustBePositive_exits() async {
		await #expect(processExitsWith: .failure) {
			// All values must be defined *inside* the closure to avoid capture
			let price: Decimals = .init(units: 1_000, scale: 2)
			_ = TickMath.roundPrice(price, tick: 0, mode: .nearest)
		}
	}
}
