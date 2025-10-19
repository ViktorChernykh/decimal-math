//
//  Decimals.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

import Foundation

/// Immutable integer amount in minor units with an explicit decimal scale.
/// Example: scale = 2 → units are cents; amount = 12345 → 123.45
public struct Decimals: Codable, Sendable, Hashable {
	public let units: Int
	public let scale: Int

	public var double: Double {
		Double(units) / Double(Int.p10[scale])
	}

	/// Creates a fixed-point decimal from integer minor units.
	///
	/// - Parameters:
	///   - units: Integer value in minor units (e.g., cents for `scale` = 2). Can be negative.
	///   - scale: Number of fractional decimal digits; typical money scales are 0...3.
	@inline(__always)
	public init(units: Int, scale: Int) {
		self.units = units
		self.scale = scale
	}

	@inline(__always)
	public init?(from string: String) {
		if let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(string) {
			units = parsed.units
			scale = parsed.scale
			return
		}
		return nil
	}

	/// Converts a Double to fixed-point `Decimals` using banker's rounding.
	///
	/// - Parameters:
	///   - value: Source floating value in major units (e.g. 123.45 when scale=2).
	///   - scale: Fractional digits count (>= 0).
	/// - Throws: `notFinite` for NaN/Inf, `overflow` if scaled value does not fit `Int`,
	///           `negativeScale` if scale < 0.
	/// - Note: Rounds with `.toNearestOrEven`, consistent with integer banker's rounding used elsewhere.
	@inline(__always)
	public init?(from value: Double, scale: Int) {
		// Validate scale
		guard scale >= 0 else {
			return nil
		}

		// Fast path multiplier
		let multiplier: Int = Int.p10[scale]

		// Scale and banker's rounding in Double domain
		// Using rounded(.toNearestOrEven) matches IEEE-754 banker's rounding.
		let scaled: Double = (value * Double(multiplier)).rounded(.toNearestOrEven)

		// Normalize negative zero: -0.0 → 0
		let normalized: Double = scaled == 0.0 ? 0.0 : scaled

		// Safe cast (already rounded)
		self.units = Int(normalized)
		self.scale = scale
	}

	/// Converts Decimal → (units, scale)
	/// Example: 5.12 → (512, 2)
	@inline(__always)
	public init(decimal: Decimal) {
		// Decimal.exponent is negative when there are fractional digits
		scale = decimal.exponent < 0 ? -decimal.exponent : 0
		if scale == 0 {
			units = NSDecimalNumber(decimal: decimal).intValue
			return
		}
		// Fast: internal base-10 power (no building Decimal 10^scale)
		let shifted: NSDecimalNumber = NSDecimalNumber(decimal: decimal)
			.multiplying(byPowerOf10: Int16(scale)) // 5.12 * 10^2 = 512
		units = shifted.intValue
	}

	/// Decodes from JSON number or string:
	/// - If value is a JSON number → decode as Decimal (precise), then map to (units, scale)
	/// - If value is a String     → parse with en_US_POSIX locale, then map
	/// - Fallback: try Double → Decimal (not recommended, but we'll leave it as a backup way).
	@inline(__always)
	public init(from decoder: any Decoder) throws {
		let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()

		// Double or Decimal
		if let decimal: Decimal = try? container.decode(Decimal.self) {
			// Decimal.exponent is negative when there are fractional digits
			scale = decimal.exponent < 0 ? -decimal.exponent : 0
			if scale == 0 {
				units = NSDecimalNumber(decimal: decimal).intValue
				return
			}
			// Fast: internal base-10 power (no building Decimal 10^scale)
			let shifted: NSDecimalNumber = NSDecimalNumber(decimal: decimal)
				.multiplying(byPowerOf10: Int16(scale)) // 5.12 * 10^2 = 512
			units = shifted.intValue
			return
		} else

		// google.type.Decimal
		if let dec: GoogleDecimal = try? container.decode(GoogleDecimal.self) {
			let trimmed: String = dec.value.trimmingCharacters(in: .whitespacesAndNewlines)

			if let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(trimmed) {
				self.units = parsed.units
				self.scale = parsed.scale
				return
			}
		} else

		// String, parse it deterministically (ASCII-only)
		if let raw: String = try? container.decode(String.self) {
			let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)

			if let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(trimmed) {
				self.units = parsed.units
				self.scale = parsed.scale
				return
			}
		}
		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected decimal number")
	}

	/// Encodes `Decimals` as a JSON number using its `double` value.
	///
	/// We intentionally use a single-value container so that JSON output is a plain
	/// number (e.g., `123.45`) rather than an object. Precision is bounded by
	/// the `Double` IEEE-754 representation and the current `scale`.
	@inline(__always)
	public func encode(to encoder: any Encoder) throws {
		var container: any SingleValueEncodingContainer = encoder.singleValueContainer()
		try container.encode(Double(units) / Double(Int.p10[scale]))
	}

	/// Changes the scale by multiplying or dividing the underlying `units` by 10^Δ.
	///
	/// - Parameter newScale: Target scale. If larger than current, multiplies; if smaller, divides with banker's rounding.
	/// - Returns: A new value at `newScale`.
	/// - Precondition: Multiplication/division must not overflow and |Δ| must be within the supported scale range.
	/// - Discussion: Downscale uses **round half to even** to avoid systemic bias.
	@inline(__always)
	public func rescaled(to newScale: Int) -> Decimals {
		if newScale == scale {
			return self
		}
		let result: Int = units.pow10(newScale - scale)

		return Decimals(units: result, scale: newScale)
	}

	// MARK: Integer rounding utility (banker's)

	/// Applies banker's rounding (round half to even) to an integer division.
	///
	/// - Parameters:
	///   - quotient: Truncated integer quotient `q = numerator / divisor`.
	///   - remainder: Integer remainder `r = numerator % divisor` (can be negative).
	///   - divisor: Positive divisor `d > 0`.
	/// - Returns: Either `q`, `q + 1`, or `q - 1` depending on half-to-even rules and the sign of `r`.
	/// - Precondition: `divisor` must be > 0.
	@inline(__always)
	public static func roundHalfToEven(quotient: Int, remainder: Int, divisor: Int) -> Int {
		precondition(divisor > 0, "Divisor must be positive in roundHalfToEven(quotient:remainder:divisor:)")

		if remainder == 0 {
			return quotient
		}
		let absR: Int = remainder >= 0 ? remainder : -remainder
		let half: Int = divisor / 2
		let isHalf: Bool = (divisor % 2 == 0) && (absR == half)
		let shouldRoundUp: Bool = isHalf ? (quotient & 1 != 0) : (absR > half)
		if !shouldRoundUp {
			return quotient
		}
		return remainder >= 0 ? quotient &+ 1 : quotient &- 1
	}

	// MARK: Integer Arithmetic

	/// Sums a sequence of fixed-point values with identical `scale`.
	///
	/// - Parameters:
	///   - values: Sequence of values to sum.
	///   - scale: Expected common scale; each element must match.
	/// - Returns: Sum with the same `scale`.
	/// - Precondition: All items must share the same scale; arithmetic must not overflow.
	@inline(__always)
	public static func sum(_ values: some Sequence<Decimals>, scale: Int) -> Decimals {
		var total: Int = 0
		for value in values {
			precondition(value.scale == scale, "Scale mismatch in sum(_:scale:)")

			let (result, overflow) = total.addingReportingOverflow(value.units)
			precondition(!overflow, "Overflow in sum(_:scale:): \(total) + \(value.units)")

			total = result
		}
		return Decimals(units: total, scale: scale)
	}

	/// Adds two fixed-point values with the same `scale`.
	///
	/// - Parameter rhs: Right-hand side value; must have the same `scale`.
	/// - Returns: Sum with the same `scale`.
	/// - Precondition: Same scale; no overflow.
	@inline(__always)
	public func add(_ rhs: Decimals) -> Decimals {
		precondition(scale == rhs.scale, "Scale mismatch in add(_:)")

		let (result, overflow) = units.addingReportingOverflow(rhs.units)
		precondition(!overflow, "Overflow in add(_:): \(units) + \(rhs.units)")

		return Decimals(units: result, scale: scale)
	}

	/// Subtracts another fixed-point value with the same `scale`.
	///
	/// - Parameter rhs: Value to subtract; must have the same `scale`.
	/// - Returns: Difference with the same `scale`.
	/// - Precondition: Same scale; no overflow.
	@inline(__always)
	public func subtract(_ rhs: Decimals) -> Decimals {
		precondition(scale == rhs.scale, "Scale mismatch in subtract(_:)")

		let (result, overflow) = units.subtractingReportingOverflow(rhs.units)
		precondition(!overflow, "Overflow in subtract(_:): \(units) - \(rhs.units)")

		return Decimals(units: result, scale: scale)
	}

	/// Multiplies by an integer factor, preserving `scale`.
	///
	/// - Parameter multiplier: Integer factor (can be negative); the result keeps the same `scale`.
	/// - Returns: Product with the same `scale`.
	/// - Precondition: No overflow.
	@inline(__always)
	public func multiply(_ multiplier: Int) -> Decimals {
		let (result, overflow) = units.multipliedReportingOverflow(by: multiplier)
		precondition(!overflow, "Overflow in multiply(_:): \(units) * \(multiplier)")

		return Decimals(units: result, scale: scale)
	}

	/// Multiplies by other Decimals, preserving `scale`, using banker's rounding.
	///
	/// - Parameter multiplier: Value to multiply.
	/// - Returns: Product with the same `scale`.
	/// - Precondition: No overflow.
	@inline(__always)
	public func multiply(_ multiplier: Decimals) -> Decimals {
		let (result, overflow) = units.multipliedReportingOverflow(by: multiplier.units)
		precondition(!overflow, "Overflow in multiply(_:): \(units) * \(multiplier.units)")

		let denominator: Int = Int.pow10(scale: multiplier.scale)
		let q: Int = result / denominator
		let r: Int = result % denominator
		let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: denominator)

		return Decimals(units: rounded, scale: scale)
	}

	/// Divides by an integer divisor using banker's rounding.
	///
	/// - Parameter divisor: Positive integer divisor; sign is normalized so the divisor is positive.
	/// - Returns: Quotient rounded to preserve `scale`.
	/// - Precondition: Divisor must be > 0; no overflow.
	@inline(__always)
	public func divide(_ divisor: Int) -> Decimals {
		precondition(divisor > 0, "Divisor must be greater than zero in divide(_:)")

		let (q, qOverflow) = units.dividedReportingOverflow(by: divisor)
		precondition(!qOverflow, "Overflow in divide(_:): \(units) / \(divisor)")

		let (r, rOverflow) = units.remainderReportingOverflow(dividingBy: divisor)
		precondition(!rOverflow, "Overflow in divide(_:): \(units) % \(divisor)")

		let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: divisor)

		return Decimals(units: rounded, scale: scale)
	}

	/// Divides by an other Decimals using banker's rounding.
	///
	/// - Parameter divisor: Positive integer divisor; sign is normalized so the divisor is positive.
	/// - Returns: Quotient rounded to preserve `scale`.
	/// - Precondition: Divisor must be > 0; no overflow.
	@inline(__always)
	public func divide(_ divisor: Decimals) -> Decimals {
		precondition(divisor.units > 0, "Divisor must be greater than zero in divide(_:)")

		let factor: Int = Int.pow10(scale: divisor.scale)
		let (numerator, overflow) = units.multipliedReportingOverflow(by: factor)
		precondition(!overflow, "Overflow in multiply(_:over:): \(units) * \(factor)")

		let denominator: Int = divisor.units
		let q: Int = numerator / denominator
		let r: Int = numerator % denominator
		let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: denominator)

		return Decimals(units: rounded, scale: scale)
	}

	/// Multiplies by a rational factor `numerator / denominator` using banker's rounding.
	///
	/// - Parameters:
	///   - numerator: Numerator of the ratio (can be negative; denominator is normalized to positive).
	///   - denominator: Denominator of the ratio; must be non-zero.
	/// - Returns: Product with the same `scale`.
	/// - Precondition: Multiplier must be non-negative; no overflow.
	@inline(__always)
	public func multiply(_ numerator: Int, over denominator: Int) -> Decimals {
		precondition(numerator >= 0, "Numerator must be non-negative in multiply(_:over:)")
		precondition(denominator > 0, "Division must be more then zero in multiply(_:over:)")

		let (num, overflow) = units.multipliedReportingOverflow(by: numerator)
		precondition(!overflow, "Overflow in multiply(_:over:): \(units) * \(numerator)")

		let (q, qOverflow) = num.dividedReportingOverflow(by: denominator)
		precondition(!qOverflow, "Overflow in multiply(_:over:): \(num) * \(numerator)")

		let (r, rOverflow) = num.remainderReportingOverflow(dividingBy: denominator)
		precondition(!rOverflow, "Overflow in multiply(_:over:): \(num) % \(denominator)")

		let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: denominator)

		return Decimals(units: rounded, scale: scale)
	}

	/// Allocates the amount proportionally to integer `weights` using the Largest Remainder method.
	///
	/// - Parameter weights: Non-negative integer weights. If all zeros, falls back to equal split.
	/// - Returns: Array of parts that sums exactly to the original amount.
	/// - Precondition: on invalid input or arithmetic overflow.
	@inline(__always)
	public func allocateProportionally(weights: [Int]) -> [Decimals] {
		precondition(!weights.isEmpty, "Weights must be non-empty in allocateProportionally(weights:)")

		let n: Int = weights.count
		var sumW: Int = 0
		for weight in weights {
			precondition(weight >= 0, "Weights must be non-negative in allocateProportionally(weights:)")
			let (sum, overflow) = sumW.addingReportingOverflow(weight)
			precondition(!overflow, "Weights sum overflow in allocateProportionally(weights:)")
			sumW = sum
		}
		if sumW == 0 {
			return splitEvenly(parts: n)
		}

		var floors: [Int] = .init(repeating: 0, count: n)
		var fracs: [(idx: Int, remNum: UInt, remDen: UInt)] = .init()
		fracs.reserveCapacity(n)

		var acc: Int = 0
		for i in 0..<n {
			let (num, overflow) = units.multipliedReportingOverflow(by: weights[i])
			precondition(!overflow, "Overflow in allocateProportionally(weights:): \(units) * \(weights[i])")

			let q: Int = num / sumW
			let r: Int = num % sumW
			floors[i] = q
			acc &+= q
			// store remainder as fraction r/sumW for later comparison
			fracs.append((idx: i, remNum: UInt(r >= 0 ? r : -r), remDen: UInt(sumW)))
		}

		var leftover: Int = units &- acc

		// Sort by remainder descending, stable by index
		fracs.sort { (a, b) -> Bool in
			if a.remNum == 0 && b.remNum == 0 {
				return a.idx < b.idx
			}
			if a.remNum == 0 {
				return false
			}
			if b.remNum == 0 {
				return true
			}
			// compare a.remNum/a.remDen vs b.remNum/b.remDen without floating point
			let lhs = a.remNum.multipliedFullWidth(by: b.remDen)
			let rhs = b.remNum.multipliedFullWidth(by: a.remDen)

			let fracGreater = if lhs.high != rhs.high {
				lhs.high > rhs.high
			} else {
				lhs.low > rhs.low
			}
			if fracGreater {
				return true
			}
			if a.remNum == b.remNum && a.remDen == b.remDen {
				return a.idx < b.idx
			}
			return false
		}
		var k: Int = 0
		while leftover > 0 && k < fracs.count {
			let i: Int = fracs[k].idx
			floors[i] &+= 1
			leftover &-= 1
			k &+= 1
		}
		return floors.map {
			Decimals(units: $0, scale: scale)
		}
	}

	// MARK: Allocation / Splitting (integer domain)

	/// Splits the amount into `parts` as evenly as possible using the Largest Remainder method.
	///
	/// - Parameter parts: Number of parts; must be greater than zero.
	/// - Returns: Array of parts that sums exactly to the original amount.
	/// - Precondition: `parts` must be > zero.
	@inline(__always)
	public func splitEvenly(parts: Int) -> [Decimals] {
		precondition(parts > 0, "Parts must be > 0 in splitEvenly(parts:)")

		let base: Int = units / parts
		var remainder: Int = units - base * parts
		var res: [Decimals] = .init(repeating: Decimals(units: base, scale: scale), count: parts)
		var i: Int = 0

		while remainder > 0 {
			res[i] = Decimals(units: res[i].units &+ 1, scale: scale)
			remainder &-= 1
			i &+= 1
			if i == parts {
				i = 0
			}
		}
		return res
	}

	// MARK: Fast ASCII Formatter (no Decimal, unsafe buffers)

	/// Formats the value to an ASCII string (e.g., "1 234 567.89") without intermediate allocations.
	///
	/// - Parameters:
	///   - groupSeparator: Thousands separator (ASCII, single-byte). Pass `nil` to disable grouping.
	///   - decimalSeparator: Fraction separator (ASCII, single-byte). Ignored if `scale == 0`.
	///   - minFractionDigits: Minimum number of fractional digits; defaults to `scale`.
	/// - Returns: ASCII string representation with optional grouping and zero-padded fractional part.
	/// - Precondition: `scale` must be within bounds supported by `Int.p10`.
	/// - Note: This formatter is ASCII-only by design for speed. Use a higher-level formatter for Unicode locales if needed.
	public func format(
		groupSeparator: Character? = " ",
		decimalSeparator: Character = ".",
		minFractionDigits: Int? = nil
	) -> String {
		let isNegative: Bool = units < 0
		let magnitude: Int = isNegative ? -units : units

		// Extract integer and fractional parts in units
		let div: Int = Int.pow10(scale: scale)
		let intPart: Int = magnitude / div
		let fracPart: Int = scale > 0 ? magnitude % div : 0

		// Precompute length: sign + digits + grouping + decimal + fraction
		let intDigits: Int = intPart == 0 ? 1 : Decimals.digits(intPart)
		let groups: Int = groupSeparator != nil ? max(0, (intDigits - 1) / 3) : 0
		let fractionWidth: Int = scale > 0 ? max(scale, minFractionDigits ?? scale) : 0
		let signWidth: Int = isNegative ? 1 : 0
		let sepWidth: Int = scale > 0 ? 1 : 0
		let capacity: Int = signWidth + intDigits + groups + (fractionWidth > 0 ? (sepWidth + fractionWidth) : 0)

		return String(unsafeUninitializedCapacity: capacity, initializingUTF8With: { (buf: UnsafeMutableBufferPointer<UInt8>) -> Int in
			var idx: Int = capacity

			func write(_ byte: UInt8) {
				idx &-= 1
				buf[idx] = byte
			}

			// Write fraction (right-aligned, zero-padded)
			if fractionWidth > 0 {
				var f: Int = fracPart
				for _ in 0..<fractionWidth {
					let digit: UInt8 = UInt8(f % 10)
					write(48 &+ digit)
					f /= 10
				}
				// Decimal separator
				write(Self.asciiCode(for: decimalSeparator))
			}

			// Write integer part with grouping
			var number: Int = intPart
			var written: Int = 0
			repeat {
				if written != 0, written % 3 == 0, let g = groupSeparator {
					write(Self.asciiCode(for: g))
				}
				let digit: UInt8 = UInt8(number % 10)
				write(48 &+ digit)
				number /= 10
				written &+= 1
			} while number > 0

			if isNegative {
				write(45) // '-'
			}

			let initializedCount: Int = capacity - idx
			if idx > 0, let base: UnsafeMutablePointer<UInt8> = buf.baseAddress {
				base.moveInitialize(from: base.advanced(by: idx), count: initializedCount)
			}
			return initializedCount
		})
	}

	// MARK: - Low-level helpers

	/// ASCII code for a Character assumed to be single-scalar (like separators).
	@inline(__always)
	private static func asciiCode(for character: Character) -> UInt8 {
		String(character).utf8.first ?? 63 // '?'
	}

	/// Number of base-10 digits in a positive integer.
	@inline(__always)
	private static func digits(_ value: Int) -> Int {
		var current: Int = value
		var count: Int = 0

		while current > 0 {
			current /= 10
			count &+= 1
		}
		return max(1, count)
	}

	/// Parses ASCII decimal string into `(units, scale)` pair.
	///
	/// Accepted forms: optional sign ('+' or '-'), digits, optional single decimal separator '.' or ',', optional exponent 'e' or 'E'.
	/// Examples: "123", "-123.45", "+0,001", "1.23e2", "-1.2E-3". Grouping separators are NOT supported.
	/// Returns `nil` on invalid input.
	@inline(__always)
	private static func parseStringToUnitsScale(_ value: String) -> (Int, Int)? {
		if value.isEmpty {
			return nil
		}

		// Mantissa state
		var sign: Int = 1
		var begin: Bool = true
		var sawDigits: Bool = false
		var sawSeparator: Bool = false
		var sawExponent: Bool = false
		var unitsAbs: Int = 0
		var scale: Int = 0

		// Exponent state
		var readingExponent: Bool = false
		var expSign: Int = 1
		var expValue: Int = 0
		var sawExpDigit: Bool = false

		// Leading/trailing spaces are trimmed by caller; internal spaces are invalid
		for byte in value.utf8 {
			switch byte {
			case 43: // '+'
				if readingExponent {
					// '+' allowed only once, immediately after 'e' / 'E'
					if sawExpDigit { return nil }
					expSign = 1
					continue
				}
				// Sign is only allowed at the very beginning, before any digit or separator
				if !begin { return nil }
				begin = false
				continue

			case 45: // '-'
				if readingExponent {
					// '-' allowed only once, immediately after 'e' / 'E'
					if sawExpDigit { return nil }
					expSign = -1
					continue
				}
				if !begin { return nil }
				begin = false
				sign = -1
				continue

			case 44, 46: // ',' or '.' as decimal separator
				if readingExponent {
					// no decimal separator allowed in exponent
					return nil
				}
				// Must have at least one digit before the separator; only one separator allowed
				if !sawDigits || sawSeparator { return nil }
				sawSeparator = true
				continue

			case 69, 101: // 'E' or 'e' → start exponent
				if readingExponent {
					// second 'e' not allowed
					return nil
				}
				// Need mantissa digits before 'e'
				if !sawDigits {
					return nil
				}
				readingExponent = true
				sawExponent = true
				continue

			default:
				break
			}

			// digits '0'...'9'
			if byte >= 48 && byte <= 57 {
				let digit: Int = Int(byte &- 48)
				if readingExponent {
					sawExpDigit = true
					// expValue = expValue * 10 + digit (bounded by Int)
					let (tmp, of1) = expValue.multipliedReportingOverflow(by: 10)
					if of1 { return nil }
					let (tmp2, of2) = tmp.addingReportingOverflow(digit)
					if of2 { return nil }
					expValue = tmp2
				} else {
					// accumulate mantissa absolute units
					unitsAbs = 10 &* unitsAbs &+ digit
					if sawSeparator {
						scale &+= 1
					}
					sawDigits = true
					begin = false
				}
			} else {
				// Any other ASCII is invalid (including spaces inside number)
				return nil
			}
		}

		// Validate mantissa
		if !sawDigits {
			return nil
		}

		// If separator was present, must have at least one fractional digit
		if sawSeparator && scale == 0 {
			return nil
		}

		// Validate exponent if present
		if sawExponent && !sawExpDigit {
			return nil
		}

		// Apply mantissa sign
		var units: Int = sign > 0 ? unitsAbs : -unitsAbs

		// Apply exponent: value = mantissa * 10^(expSign * expValue)
		if sawExponent && expValue != 0 {
			let exp: Int = expSign > 0 ? expValue : -expValue
			if exp > 0 {
				// shift decimal point to the right by 'exp'
				if exp >= scale {
					let shift: Int = exp - scale
					let mul: Int = Int.pow10(scale: shift)
					let (res, of) = units.multipliedReportingOverflow(by: mul)
					if of { return nil }
					units = res
					scale = 0
				} else {
					scale &-= exp
				}
			} else {
				// negative exponent: increase fractional digits
				let increase: Int = -exp
				// ensure target scale is representable
				let newScale: Int = scale &+ increase
				// Guard against out-of-range scales
				if newScale < 0 { return nil }
				scale = newScale
				// units unchanged
			}
		}

		return (units, scale)
	}
}

/// `google.type.Decimal` representation as used by Google APIs.
/// Holds a base-10 decimal value as a string without exponent or special values.
struct GoogleDecimal: Codable, Sendable {
	/// Decimal value represented as a string.
	let value: String

	init(value: String) {
		self.value = value
	}
}
