@testable import DecimalMath
import Testing

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

	// MARK: - add / subtract / sum

	@Test("add/subtract keep scale and compute exact integer result")
	func add_subtract() {
		let a: Decimals = .init(units: 12_300, scale: 2)
		let b: Decimals = .init(units: -450, scale: 2)

		let sum: Decimals = a.add(b)
		let diff: Decimals = a.subtract(b)

		#expect(sum.units == 11_850)
		#expect(sum.scale == 2)

		#expect(diff.units == 12_750)
		#expect(diff.scale == 2)
	}

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

	// MARK: - multiply / divide

	@Test("multiply by integer preserves scale")
	func multiply_integer() {
		let a: Decimals = .init(units: 12_345, scale: 2)
		let r: Decimals = a.multiply(3)
		#expect(r.units == 37_035)
		#expect(r.scale == 2)
	}

	@Test("divide by integer uses banker's rounding")
	func divide_bankers() {
		// 1.25 / 2 = 0.625 → scale 2 banker’s → 0.62 (even)
		let a: Decimals = .init(units: 125, scale: 2)
		let half: Decimals = a.divide(2)
		#expect(half.units == 62)

		// Negative: -1.25 / 2 = -0.625 → 0.62 with sign
		let b: Decimals = .init(units: -125, scale: 2)
		let halfNeg: Decimals = b.divide(2)
		#expect(halfNeg.units == -62)
	}

	// MARK: - multiply (ratio)

	@Test("multiply by rational with banker's rounding")
	func multiply_ratio() {
		// 100.00 * (1/3) = 33.333... → 33.33 (banker's)
		let a: Decimals = .init(units: 10_000, scale: 2)
		let r: Decimals = a.multiply(1, over: 3)
		#expect(r.units == 3_333)
		#expect(r.scale == 2)

		// 1.05 * 1/2 = 0.525 → 0.52 (banker’s)
		let b: Decimals = .init(units: 105, scale: 2)
		let r2: Decimals = b.multiply(1, over: 2)
		#expect(r2.units == 52)
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
}
