@testable import DecimalMath
import Testing

struct LotMathTests {

	// MARK: - On-grid behavior

	@Test("roundQuantity: on-grid quantity stays unchanged for all modes")
	func onGrid_stays() {
		let quantity: Int = 120
		let lotSize: Int = 10

		#expect(LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .floor)   == 120)
		#expect(LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .ceil)    == 120)
		#expect(LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .nearest) == 120)
	}

	// MARK: - Off-grid positive quantities

	@Test("roundQuantity: floor/ceil/nearest on off-grid positive quantity")
	func offGrid_positive() {
		let quantity: Int = 123
		let lotSize: Int = 10

		let floored: Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .floor)   // 120
		let ceiled:  Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .ceil)    // 130
		let nearest: Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .nearest) // 120 (3 < 5)

		#expect(floored == 120)
		#expect(ceiled  == 130)
		#expect(nearest == 120)
	}

	// MARK: - Off-grid negative quantities (short)

	@Test("roundQuantity: floor/ceil/nearest on off-grid negative quantity")
	func offGrid_negative() {
		let quantity: Int = -123
		let lotSize: Int = 10

		// floor → toward -∞: -130
		let floored: Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .floor)
		// ceil  → toward +∞: -120
		let ceiled:  Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .ceil)
		// nearest: |rem|=3 < 5 → -120 (toward zero)
		let nearest: Int = LotMath.roundQuantity(quantity, lotSize: lotSize, mode: .nearest)

		#expect(floored == -130)
		#expect(ceiled  == -120)
		#expect(nearest == -120)
	}

	// MARK: - Half-to-even tiebreak (even lot size only)

	@Test("roundQuantity: nearest uses half-to-even on exact half-lot (even lot size)")
	func nearest_halfToEven_evenLot() {
		let lotSize: Int = 10 // even, half = 5

		// div even (12), q = 12*10 + 5 = 125 → tie → stay at 120
		let evenDivQty: Int = 125
		let evenResult: Int = LotMath.roundQuantity(evenDivQty, lotSize: lotSize, mode: .nearest)
		#expect(evenResult == 120)

		// div odd (11), q = 11*10 + 5 = 115 → tie → move to 120 (even boundary)
		let oddDivQty: Int = 115
		let oddResult: Int = LotMath.roundQuantity(oddDivQty, lotSize: lotSize, mode: .nearest)
		#expect(oddResult == 120)

		// negative tie: -125 → div = -12 (even), rem = -5 → stay at -120
		let negativeTie: Int = -125
		let negativeResult: Int = LotMath.roundQuantity(negativeTie, lotSize: lotSize, mode: .nearest)
		#expect(negativeResult == -120)
	}

	// MARK: - clampQuantity

	@Test("clampQuantity: returns bounds when out of range, identity otherwise")
	func clamp_basic() {
		let lowerBound: Int = 100
		let upperBound: Int = 200

		#expect(LotMath.clampQuantity(50,  min: lowerBound, max: upperBound) == 100)
		#expect(LotMath.clampQuantity(250, min: lowerBound, max: upperBound) == 200)
		#expect(LotMath.clampQuantity(150, min: lowerBound, max: upperBound) == 150)
	}
}
