@testable import DecimalMath
import Testing

struct LotMathExitTests {

	// MARK: - roundQuantity preconditions

	@Test("roundQuantity: lotSize must be > 0 (precondition)")
	func roundQuantity_invalidLot_exits() async {
		await #expect(processExitsWith: .failure) {
			let quantity: Int = 100
			let invalidLot: Int = 0
			_ = LotMath.roundQuantity(quantity, lotSize: invalidLot, mode: .floor)
		}
	}

	// MARK: - clampQuantity preconditions

	@Test("clampQuantity: min must be <= max (precondition)")
	func clamp_invalidBounds_exits() async {
		await #expect(processExitsWith: .failure) {
			let value: Int = 150
			let minBound: Int = 200
			let maxBound: Int = 100
			_ = LotMath.clampQuantity(value, min: minBound, max: maxBound)
		}
	}
}
