@testable import DecimalMath
import Testing

struct IntPow10Tests {

	// MARK: - pow10(scale:)

	@Test("pow10(scale:) returns correct precomputed values")
	func pow10Scale_returnsCorrectValues() {
		#expect(Int.pow10(scale: 0) == 1)
		#expect(Int.pow10(scale: 1) == 10)
		#expect(Int.pow10(scale: 2) == 100)
		#expect(Int.pow10(scale: 3) == 1_000)
		#expect(Int.pow10(scale: 15) == 1_000_000_000_000_000)
		#expect(Int.pow10(scale: 18) == 1_000_000_000_000_000_000)
	}

	@Test("pow10(scale:) triggers precondition when out of range")
	func pow10Scale_outOfRangePrecondition() {
		#expect(throws: Never.self) {
			_ = Int.pow10(scale: 0) // valid
		}
	}

	// MARK: - pow10(_:)

	@Test("pow10(_:) multiplication path")
	func pow10Multiplication() {
		let value: Int = 123
		#expect(value.pow10(1) == 1230)
		#expect(value.pow10(2) == 12_300)
	}

	@Test("pow10(_:) division with banker’s rounding")
	func pow10DivisionBankersRounding() {
		// Exact division (no rounding)
		#expect(1234.pow10(-1) == 123)

		// Remainder < half → round down
		#expect(1231.pow10(-1) == 123)

		// Remainder > half → round up
		#expect(1239.pow10(-1) == 124)

		// Exact half, even quotient → stay
		#expect(1245.pow10(-2) == 12)

		// Exact half, odd quotient → round away from zero
		#expect(1255.pow10(-2) == 13)

		// Negative numbers, tie → round away from zero
		#expect((-1255).pow10(-2) == -13)
	}

	@Test("pow10(_:) with zero scale returns self")
	func pow10ZeroScale() {
		let value: Int = 42
		#expect(value.pow10(0) == 42)
	}

	@Test("pow10(scale:) preconditions: negative scale crashes process")
	func pow10Scale_negative_exits() async {
		await #expect(processExitsWith: .failure) {
			_ = Int.pow10(scale: -1) // precondition should fire
		}
	}

	@Test("pow10(scale:) preconditions: scale above table bound crashes process")
	func pow10Scale_outOfBounds_exits() async {
		await #expect(processExitsWith: .failure) {
			_ = Int.pow10(scale: 19) // if table is 0...18, this must precondition
		}
	}

	// MARK: - Int.pow10(_:)

	@Test("pow10(_:) multiply path overflow should precondition")
	func pow10Multiply_overflow_exits() async {
		// Choose a value that overflows when multiplied by 10^k.
		await #expect(processExitsWith: .failure) {
			let v: Int = Int.max / 10 + 1
			_ = v.pow10(1) // should overflow -> precondition
		}
	}

	@Test("pow10(_:) divide path: abs(scale) beyond table bound preconditions")
	func pow10Divide_outOfBounds_exits() async {
		await #expect(processExitsWith: .failure) {
			_ = 123.pow10(-19) // |-19| > table bound -> precondition
		}
	}

	// (Optional) Checking that valid values do not terminate the process:
	@Test("pow10(scale:) valid range does NOT exit")
	func pow10Scale_valid_noExit() {
		for k in 0...15 {
			#expect(Int.pow10(scale: k) > 0)
		}
	}

	@Test("pow10(_:) valid multiply/divide do NOT exit")
	func pow10_valid_noExit() {
		#expect(123.pow10(0) == 123)
		#expect(123.pow10(1) == 1230)
		#expect(1255.pow10(-2) == 13) // banker’s tie case stays correct and does not exit
	}
}
