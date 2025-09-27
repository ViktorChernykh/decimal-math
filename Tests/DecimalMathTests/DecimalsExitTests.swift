@testable import DecimalMath
import Testing

struct DecimalsExitTests {

	// MARK: - rescaled(to:) preconditions

	@Test("rescaled(to:) preconditions: |Δ| beyond pow10 table → process exits")
	func rescaled_outOfBounds_exits() async {
		await #expect(processExitsWith: .failure) {
			let value: Decimals = .init(units: 1, scale: 0)
			_ = value.rescaled(to: 99) // out of bounds in your pow10 table
		}
	}

	// MARK: - divide(_:)

	@Test("divide(_:) preconditions: divisor must be > 0")
	func divide_zero_exits() async {
		await #expect(processExitsWith: .failure) {
			let value: Decimals = .init(units: 100, scale: 2)
			_ = value.divide(0)
		}
	}

	// MARK: - multiply(_:over:)

	@Test("multiply(_:over:) preconditions: denominator must be > 0")
	func multiply_over_zero_den_exits() async {
		await #expect(processExitsWith: .failure) {
			let value: Decimals = .init(units: 100, scale: 2)
			_ = value.multiply(1, over: 0)
		}
	}

	@Test("multiply(_:over:) preconditions: numerator must be non-negative")
	func multiply_over_negative_num_exits() async {
		await #expect(processExitsWith: .failure) {
			let value: Decimals = .init(units: 100, scale: 2)
			_ = value.multiply(-1, over: 2)
		}
	}

	// MARK: - allocateProportionally(weights:)

	@Test("allocateProportionally: empty weights precondition")
	func allocate_empty_weights_exits() async {
		await #expect(processExitsWith: .failure) {
			let total: Decimals = .init(units: 100, scale: 0)
			_ = total.allocateProportionally(weights: [])
		}
	}

	@Test("allocateProportionally: negative weight precondition")
	func allocate_negative_weight_exits() async {
		await #expect(processExitsWith: .failure) {
			let total: Decimals = .init(units: 100, scale: 0)
			_ = total.allocateProportionally(weights: [1, -1])
		}
	}

	// MARK: - splitEvenly(parts:)

	@Test("splitEvenly: parts must be > 0")
	func split_evenly_zero_parts_exits() async {
		await #expect(processExitsWith: .failure) {
			let total: Decimals = .init(units: 100, scale: 0)
			_ = total.splitEvenly(parts: 0)
		}
	}
}
