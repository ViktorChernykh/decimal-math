@testable import DecimalMath
import Foundation
import Testing

@Suite("Binary operators on Decimals (banker's rounding, scale preservation, sign handling)")
struct DecimalsTests {

	// MARK: - rescaled(to:)

	@Test("rescaled(up): multiplies by 10^Δ without rounding")
	func rescaled_up_multiplies() {
		let value: Decimals = .init(units: 123, scale: 0)
		let up: Decimals = value.rescaled(to: 2)
		#expect(up.scale == 2)
		#expect(up.units == 12_300)
	}

	@Test("rescaled(down): uses banker's rounding (half-to-even)")
	func rescaled_down_bankers() {
		// 12.345 → scale 2
		let v1: Decimals = .init(units: 1_234_5, scale: 3).rescaled(to: 2)  // 12.345 → 12.34 (tie towards even? no, remainder < half)
		#expect(v1.units == 1_234)

		// Exact .5 case to test half-to-even:
		// 12.350 → scale 2: 12.35 → remainder = 50 when dividing by 100 (exact half)
		// quotient = 12.35 at scale2 means units 1_235 at scale2 already; craft at scale3:
		let v2: Decimals = .init(units: 1_235_5, scale: 3).rescaled(to: 2) // 12.350 → 12.35 (even stays even? 1235/10 tie with quotient 123 = odd? )
		#expect(v2.units == 1_236)

		// Simpler explicit tie case: 125 → scale 1 from scale 2 (1.25 → 1.2 because 1 is odd? Actually: 1.25 rounding to 1 decimal = 1.2 since 1.2 is even at the last digit)
		let t1: Decimals = .init(units: 125, scale: 2).rescaled(to: 1) // 1.25 → 1.2
		#expect(t1.units == 12)

		// Another tie where even rounds up:
		// 1.150 → to 1 decimal → 1.2 because 1.1 is odd in last digit, banker’s picks even 1.2
		let t2: Decimals = .init(units: 115, scale: 2).rescaled(to: 1)
		#expect(t2.units == 12)

		// Negative tie: -1.25 → -1.2 (away or banker’s with sign handled)
		let t3: Decimals = .init(units: -125, scale: 2).rescaled(to: 1)
		#expect(t3.units == -12)
	}

	// MARK: - sum

	@Test("sum over sequence with uniform scale")
	func sum_sequence() {
		let xs: [Decimals] = [
			.init(units: 1, scale: 0),
			.init(units: 2, scale: 0),
			.init(units: 3, scale: 0),
		]
		let s: Decimals = Decimals.sum(xs, scale: 0)

		#expect(s.units == 6)
		#expect(s.scale == 0)
	}

	// MARK: - allocateProportionally / splitEvenly

	@Test("splitEvenly distributes remainder to lowest indices first")
	func split_evenly() {
		let total: Decimals = .init(units: 10, scale: 0)
		let parts: [Decimals] = total.splitEvenly(parts: 3)
		let unitsArray: [Int] = parts.map { $0.units }

		#expect(unitsArray == [4, 3, 3])
		#expect(Decimals.sum(parts, scale: 0).units == 10)
	}

	@Test("allocateProportionally honors weights and sums back to the total")
	func allocate_proportional() {
		let total: Decimals = .init(units: 10, scale: 0)
		// weights 1,2,3 → ideal shares 1.666.., 3.333.., 5.0 → floors 1,3,5 (already sums to 9) + 1 leftover → goes to largest remainder (index 0)
		let parts: [Decimals] = total.allocateProportionally(weights: [1, 2, 3])
		let unitsArray: [Int] = parts.map { $0.units }

		#expect(unitsArray.reduce(0, +) == 10)
		// Deterministic order: remainder(1/6) > remainder(0/6) etc. Expect [2,3,5]
		#expect(unitsArray == [2, 3, 5])
	}

	// MARK: - format

	@Test("format builds ASCII string with grouping and fixed fraction width")
	func format_ascii() {
		let value: Decimals = .init(units: 1_234_567_89, scale: 2) // 1_234_567.89
		let s1: String = value.format(groupSeparator: " ", decimalSeparator: ".", minFractionDigits: 2)
		#expect(s1 == "1 234 567.89")

		// Negative, scale 0
		let neg: Decimals = .init(units: -12_345, scale: 0)
		let s2: String = neg.format(groupSeparator: " ", decimalSeparator: ",", minFractionDigits: 0)
		#expect(s2 == "-12 345")
	}

	// MARK: - roundHalfToEven (direct)

	@Test("roundHalfToEven: exact half cases (even/odd)")
	func round_half_to_even_direct() {
		// quotient even, tie → stay
		do {
			let q: Int = 12
			let r: Int = 50   // divisor 100 → half = 50
			let d: Int = 100
			let rr: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: d)
			#expect(rr == 12)
		}
		// quotient odd, tie → move to even (round up)
		do {
			let q: Int = 13
			let r: Int = 50
			let d: Int = 100
			let rr: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: d)
			#expect(rr == 14)
		}
		// negative remainder (tie), should move towards even respecting sign
		do {
			let q: Int = 13
			let r: Int = -50
			let d: Int = 100
			let rr: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: d)
			#expect(rr == 12)
		}
	}
	/// Tests for `Decimals.parseStringToUnitsScale(_:)` via public initializer `init?(from:)`.
	@Test("Parse valid ASCII numeric strings ('.' and ',')")
	func testParseValidAsciiStrings() throws {
		let cases: [(source: String, expUnits: Int, expScale: Int)] = [
			("0", 0, 0),
			("-0", 0, 0),
			("+123", 123, 0),
			("12.34", 1234, 2),
			("12,34", 1234, 2),
			("-0,001", -1, 3),
			("00123.0450", 1230450, 4)
		]

		for item in cases {
			let value: Decimals? = .init(from: item.source)
			#expect(value != nil, "Should parse: \(item.source)")
			#expect(value?.units == item.expUnits, "Units mismatch for \(item.source)")
			#expect(value?.scale == item.expScale, "Scale mismatch for \(item.source)")
		}
	}

	/// Ensures invalid strings are rejected (returning `nil`).
	@Test("Reject invalid ASCII strings")
	func testParseInvalidAsciiStrings() throws {
		let invalid: [String] = [
			"",
			".",
			",",
			"+.5",
			".5",
			"123.",
			"12..3",
			"1 2",
			"+",
			"-"
		]
		for source in invalid {
			let value: Decimals? = .init(from: source)
			#expect(value == nil, "Should reject: \(source)")
		}
	}

	// MARK: Addition

	/// Adding with same scale; no rounding.
	@Test
	func add_sameScale() {
		let a: Decimals = Decimals(units: 123, scale: 2)	// 1.23
		let b: Decimals = Decimals(units: 246, scale: 2)	// 2.46
		let c: Decimals = a + b								// 3.69
		#expect(c.units == 369)
		#expect(c.scale == 2)
	}

	/// Adding with different scales; RHS downscales with banker's rounding to LHS scale.
	@Test
	func add_scaleMismatch_roundHalfToEven() {
		let a: Decimals = Decimals(units: 100, scale: 2)   // 1.00 (lhs.scale = 2)

		// 0.005 with scale=3 → to 2 decimals with banker's rounding = 0.00 (tie to even)
		let b1: Decimals = Decimals(units: 5, scale: 3)
		let r1: Decimals = a + b1
		#expect(r1.units == 100)	// 1.00
		#expect(r1.scale == 2)

		// 0.015 with scale=3 → to 2 decimals with banker's = 0.02 (tie goes to even = .02)
		let b2: Decimals = Decimals(units: 15, scale: 3)
		let r2: Decimals = a + b2
		#expect(r2.units == 102)	// 1.02
		#expect(r2.scale == 2)
	}

	// MARK: Subtraction

	@Test
	func subtract_sameScale() {
		let a: Decimals = Decimals(units: 500, scale: 2)	// 5.00
		let b: Decimals = Decimals(units: 131, scale: 2)	// 1.31
		let c: Decimals = a - b								// 3.69
		#expect(c.units == 369)	// 3.69
		#expect(c.scale == 2)
	}

	@Test
	func subtract_scaleMismatch_roundHalfToEven() {
		let a: Decimals = Decimals(units: 100, scale: 2)	// 1.00

		// 0.005 → 0.00 (even), 1.00 - 0.00 = 1.00
		let b1: Decimals = Decimals(units: 5, scale: 3)
		let r1: Decimals = a - b1
		#expect(r1.units == 100)
		#expect(r1.scale == 2)

		// 0.015 → 0.02 (even), 1.00 - 0.02 = 0.98
		let b2: Decimals = Decimals(units: 15, scale: 3)
		let r2: Decimals = a - b2
		#expect(r2.units == 98)
		#expect(r2.scale == 2)
	}

	// MARK: Multiplication (Decimals × Decimals)

	@Test
	func multiply_basic_noRounding() {
		// 1.20 × 3.00 = 3.60, lhs.scale = 2 must be preserved
		let a: Decimals = Decimals(units: 120, scale: 2)
		let b: Decimals = Decimals(units: 300, scale: 2)
		let c: Decimals = a * b
		#expect(c.units == 360)
		#expect(c.scale == 2)
	}

	@Test
	func multiply_roundHalfToEven_downscale() {
		// 1.25 × 0.50 = 0.625 → to 2 decimals: 0.62 (tie to even: .62 vs .63)
		let a: Decimals = Decimals(units: 125, scale: 2)
		let b: Decimals = Decimals(units: 50, scale: 2)
		let r1: Decimals = a * b
		#expect(r1.units == 62)
		#expect(r1.scale == 2)

		// 1.35 × 0.50 = 0.675 → to 2 decimals: 0.68 (tie to even)
		let c: Decimals = Decimals(units: 135, scale: 2)
		let r2: Decimals = c * b
		#expect(r2.units == 68)
		#expect(r2.scale == 2)
	}

	// MARK: Multiplication (× Int)

	@Test
	func multiply_byInt() {
		let a: Decimals = Decimals(units: 123, scale: 2)	// 1.23
		let r: Decimals = a * 3								// 3.69
		#expect(r.units == 369)
		#expect(r.scale == 2)
	}

	// MARK: Division (Decimals ÷ Decimals)

	@Test
	func divide_basic_roundHalfToEven() {
		// 1.00 / 8.00 = 0.125 → to 2 decimals: 0.12 (tie to even)
		let a: Decimals = Decimals(units: 100, scale: 2)
		let b: Decimals = Decimals(units: 800, scale: 2)
		let r1: Decimals = a / b
		#expect(r1.units == 12)
		#expect(r1.scale == 2)

		// -1.00 / 8.00 = -0.125 → -0.12 (banker's rounding is symmetric)
		let c: Decimals = Decimals(units: -100, scale: 2)
		let r2: Decimals = c / b
		#expect(r2.units == -12)
		#expect(r2.scale == 2)
	}

	@Test
	func divide_roundHalfToEven_various() {
		// 1.00 / 6.00 = 0.1666… → 0.17
		let a: Decimals = Decimals(units: 100, scale: 2)
		let b: Decimals = Decimals(units: 600, scale: 2)
		let r1: Decimals = a / b
		#expect(r1.units == 17)
		#expect(r1.scale == 2)

		// 2.00 / 3.00 = 0.6666… → 0.67
		let c: Decimals = Decimals(units: 200, scale: 2)
		let d: Decimals = Decimals(units: 300, scale: 2)
		let r2: Decimals = c / d
		#expect(r2.units == 67)
		#expect(r2.scale == 2)
	}


	@Test("multiply(_:over:) numerator can be negative")
	func multiply_over_negative_num_exits() {
		let value: Decimals = .init(units: 100, scale: 2)
		let newValue: Decimals = value.multiply(-1, over: 2)
		#expect(newValue.units == -50)
		#expect(newValue.scale == 2)
	}

	// MARK: Division (÷ Int)

	@Test
	func divide_byInt_roundHalfToEven_positive() {
		// 1.00 / 8 = 0.125 → 0.12
		let a: Decimals = Decimals(units: 100, scale: 2)
		let r: Decimals = a / 8
		#expect(r.units == 12)
		#expect(r.scale == 2)
	}

	@Test
	func divide_byInt_roundHalfToEven_negativeDivisor() {
		// 1.00 / -8 = -0.125 → -0.12
		let a: Decimals = Decimals(units: 100, scale: 2)
		let r: Decimals = a / -8
		#expect(r.units == -12)
		#expect(r.scale == 2)
	}

	@Test
	func divide_byInt_roundHalfToEven_negativeDividend() {
		// -1.00 / 8 = -0.125 → -0.12
		let a: Decimals = Decimals(units: -100, scale: 2)
		let r: Decimals = a / 8
		#expect(r.units == -12)
		#expect(r.scale == 2)
	}

	// MARK: Comparisons

	@Test
	func equality_scaleMismatch() {
		// 1.200 == 1.20
		let a: Decimals = Decimals(units: 1200, scale: 3)
		let b: Decimals = Decimals(units: 120, scale: 2)
		#expect(a == b)
		#expect(!(a != b))
	}

	@Test
	func ordering_scaleMismatch() {
		// 1.199 < 1.20
		let a: Decimals = Decimals(units: 1199, scale: 3)
		let b: Decimals = Decimals(units: 120, scale: 2)
		#expect(a < b)
		#expect(b > a)

		// 1.200 <= 1.20 and >=
		let c: Decimals = Decimals(units: 1200, scale: 3)
		#expect(c <= b)
		#expect(c >= b)
	}

	@Test
	func comparisons_withNegatives() {
		let a: Decimals = Decimals(units: -100, scale: 2)  // -1.00
		let b: Decimals = Decimals(units: 0, scale: 2)     //  0.00
		let c: Decimals = Decimals(units: 50, scale: 2)    //  0.50

		#expect(a < b)
		#expect(b < c)
		#expect(a < c)
		#expect(!(a > b))
		#expect(!(b > c))
	}

	// MARK: - Decimal

	@Test
	func testDecimalWithoutFractionScaleZeroPositive() {
		let value: Decimals = .init(units: 12345, scale: 0)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(12345)

		#expect(decimal == expected)
	}

	@Test
	func testDecimalWithoutFractionScaleZeroNegative() {
		let value: Decimals = .init(units: -987, scale: 0)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(-987)

		#expect(decimal == expected)
	}

	@Test
	func testDecimalSimplePositiveScaleTwo() {
		let value: Decimals = .init(units: 12345, scale: 2)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "123.45")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalSimpleNegativeScaleTwo() {
		let value: Decimals = .init(units: -12345, scale: 2)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "-123.45")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalWhenScaleEqualsDigitsCount() {
		// 123 with scale 3 → 0.123
		let value: Decimals = .init(units: 123, scale: 3)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "0.123")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalWhenScaleGreaterThanDigitsCount() {
		// 5 with scale 2 → 0.05
		let value: Decimals = .init(units: 5, scale: 2)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "0.05")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalWhenScaleMuchGreaterThanDigitsCount() {
		// 5 with scale 4 → 0.0005
		let value: Decimals = .init(units: 5, scale: 4)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "0.0005")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalZeroWithZeroScale() {
		let value: Decimals = .init(units: 0, scale: 0)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(0)

		#expect(decimal == expected)
	}

	@Test
	func testDecimalZeroWithPositiveScale() {
		let value: Decimals = .init(units: 0, scale: 3)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "0.000")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalNegativeWithScaleGreaterThanDigitsCount() {
		// -7 with scale 3 → -0.007
		let value: Decimals = .init(units: -7, scale: 3)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "-0.007")!

		#expect(decimal == expected)
	}

	@Test
	func testDecimalLargerNumberWithFraction() {
		// 123456789 with scale 4 → 12345.6789
		let value: Decimals = .init(units: 123_456_789, scale: 4)

		let decimal: Decimal = value.decimal
		let expected: Decimal = Decimal(string: "12345.6789")!

		#expect(decimal == expected)
	}
}
