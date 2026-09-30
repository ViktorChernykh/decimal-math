//
//  Decimals.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

import Foundation

public extension CodingUserInfoKey {
	static let scale: CodingUserInfoKey = {
		guard let key: CodingUserInfoKey = .init(rawValue: "scale") else {
			fatalError("Unable to create CodingUserInfoKey.scale")
		}
		return key
	}()
}

extension Decimals: Hashable {
	public func hash(into hasher: inout Hasher) {
		guard units != 0 else {
			// Every representation of zero has the same numeric value, regardless of scale.
			hasher.combine(0)
			hasher.combine(0)
			return
		}

		// Remove insignificant trailing decimal zeroes so numerically equal representations,
		// such as 1.20 and 1.200, contribute identical components to the hash.
		var canonicalUnits: Int = units
		var canonicalScale: Int = scale
		while canonicalScale > Int.min, canonicalUnits.isMultiple(of: 10) {
			canonicalUnits /= 10
			canonicalScale -= 1
		}

		hasher.combine(canonicalUnits)
		hasher.combine(canonicalScale)
	}
}

/// Immutable integer amount in minor units with an explicit decimal scale.
/// Example: scale = 2 → units are cents; amount = 12345 → 123.45
public struct Decimals: Codable, Sendable, CustomStringConvertible {
	private enum CodingKeys: String, CodingKey {
		case units
		case scale
	}

	public static let zero: Decimals = .init(units: 0, scale: 0)

	/// The largest |scale| the type supports: `Int.p10` holds powers up to 10^18.
	static let maxScale: Int = 18

	public let units: Int
	public let scale: Int

	public var abs: Decimals {
		units >= 0 ? self : self * -1
	}

	public var double: Double {
		if scale >= 0 {
			return Double(units) / Double(Int.p10[scale])
		} else {
			let absScale: Int = -scale
			return Double(units) * Double(Int.p10[absScale])
		}
	}

	/// Fast string representation with decimal point inserted `scale` digits from the right.
	/// Example: units = 12345, scale = 2 -> "123.45"; units = -7, scale = 3 -> "-0.007".
	public var description: String {
		if scale == 0 {
			return String(units)
		}

		if scale < 0 {
			let multiplier: Int = Int.p10[-scale]
			// number = units * 10^absScale (major units, no fractional part)
			let (number, overflow) = units.multipliedReportingOverflow(by: multiplier)
			precondition(!overflow, "Overflow in description for negative scale")

			return String(number)
		}

		// scale > 0 — current branch with a dot
		var digits: String = String(units.magnitude)

		// Ensure we have at least `scale + 1` digits so that the decimal point can be inserted.
		if digits.count <= scale {
			let zerosToPrepend: Int = scale - digits.count + 1
			let prefix: String = String(repeating: "0", count: zerosToPrepend)
			digits = prefix + digits
		}

		// Insert the decimal point `scale` characters from the right.
		let index: String.Index = digits.index(digits.endIndex, offsetBy: -scale)
		digits.insert(".", at: index)

		// Restore sign if the original value was negative.
		if units < 0 {
			digits.insert("-", at: digits.startIndex)
		}

		return digits
	}

	public var decimal: Decimal {
		// No fractional part
		if scale == 0 {
			return Decimal(units)
		}

		if scale < 0 {
			let absScale: Int = -scale
			let number: NSDecimalNumber = NSDecimalNumber(value: units)
				.multiplying(byPowerOf10: Int16(absScale)) // units * 10^absScale
			return number.decimalValue
		}

		let isNegative: Bool = units < 0
		let magnitude: Int = isNegative ? -units : units

		// String only for the modulus of a number
		var digits: String = String(magnitude)

		// We guarantee that the length is >= scale + 1 so that the point can be inserted correctly.
		if digits.count <= scale {
			let zerosToPrepend: Int = scale - digits.count + 1
			let prefix: String = String(repeating: "0", count: zerosToPrepend)
			digits = prefix + digits
		}

		// Index to insert point: scale characters from end
		let index: String.Index = digits.index(digits.endIndex, offsetBy: -scale)
		digits.insert(".", at: index)

		// Return the sign if there was one.
		if isNegative {
			digits.insert("-", at: digits.startIndex)
		}

		return Decimal(string: digits) ?? 0
	}

	/// Creates a fixed-point decimal from integer minor units.
	///
	/// - Parameters:
	///   - units: Integer value in minor units (e.g., cents for `scale` = 2). Can be negative.
	///   - scale: Number of fractional decimal digits; typical money scales are 0...3.
	@inline(__always)
	public init(units: Int = 0, scale: Int = 0) {
		self.units = units
		self.scale = scale
	}

	/// Parses a decimal text such as "123.45", "-1.2e3" or ".5".
	///
	/// - Parameter string: ASCII text without spaces around it.
	/// - Returns: `nil` when the text is not a number or the value does not fit: `units`
	///   outside `-Int.max...Int.max` or a scale above 18. Zero always fits.
	@inline(__always)
	public init?(from string: String) {
		guard let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(string),
			let value: Decimals = Decimals.fitted(
				mantissa: parsed.units,
				naturalScale: parsed.scale,
				targetScale: nil
			) else {
			return nil
		}
		self = value
	}

	/// Converts a Double to fixed-point `Decimals` using banker's rounding.
	///
	/// - Parameters:
	///   - value: Source floating value in major units (e.g. 123.45 when scale=2).
	///   - scale: Fractional digits count.
	/// - Note: Rounds with `.toNearestOrEven`, consistent with integer banker's rounding used elsewhere.
	@inline(__always)
	public init(from value: Double, scale: Int) {
		let absScale: Int = scale >= 0 ? scale : -scale
		let multiplier: Int = Int.p10[absScale]
		let scaled: Double

		if scale < 0 {
			// Scale and banker's rounding in Double domain
			// Using rounded(.toNearestOrEven) matches IEEE-754 banker's rounding.
			scaled = (value / Double(multiplier)).rounded(.toNearestOrEven)
		} else {
			// Scale and banker's rounding in Double domain
			// Using rounded(.toNearestOrEven) matches IEEE-754 banker's rounding.
			scaled = (value * Double(multiplier)).rounded(.toNearestOrEven)
		}

		// Normalize negative zero: -0.0 → 0
		let normalized: Double = scaled == 0.0 ? 0.0 : scaled

		// Safe cast (already rounded)
		self.units = Int(normalized)
		self.scale = scale
	}

	/// Converts `Decimal` to `(units, scale)`.
	/// Example: 5.12 → (512, 2).
	///
	/// - Parameters:
	///   - decimal: The source value.
	///   - targetScale: The scale of the result, -18...18. The value is rounded to it half to
	///     even. `nil` keeps the scale of the value itself.
	/// - Returns: `nil` when the value does not fit: NaN, a mantissa outside
	///   `-Int.max...Int.max`, a scale above 18 without a target, a target outside -18...18,
	///   a shift to the target above 18 or an overflow on it. Zero always fits.
	@inline(__always)
	public init?(decimal: Decimal, scale targetScale: Int? = nil) {
		guard let parts: (mantissa: Int, scale: Int) = Decimals.parts(of: decimal),
			let value: Decimals = Decimals.fitted(
				mantissa: parts.mantissa,
				naturalScale: parts.scale,
				targetScale: targetScale
			) else {
			return nil
		}
		self = value
	}

	/// Decodes from JSON number or string:
	/// - If value is a JSON number → decode as Decimal (precise), then map to (units, scale)
	/// - If value is a google.type.Decimal     → parse with en_US_POSIX locale, then map
	/// - If value is a String     → parse with en_US_POSIX locale, then map
	/// Double is not used as a separate path intentionally,
	/// so as not to pick up unnecessary artifacts of binary representation.
	///
	/// A value from outside never stops the process. A value that does not fit gives an error
	/// with the path of the field (ADR bcs-json-parser/0001).
	///
	/// - Parameter decoder: The decoder. `userInfo[.scale]` sets the scale of a JSON number.
	/// - Throws: `DecodingError.dataCorrupted` when the value is not a number or does not fit;
	///   `DecodingError.keyNotFound` when the object form misses a key.
	@inline(__always)
	public init(from decoder: any Decoder) throws {
		let container: any SingleValueDecodingContainer = try decoder.singleValueContainer()

		// Decimal
		if let decimal: Decimal = try? container.decode(Decimal.self) {
			// The caller of the decoder may set the scale of the result.
			let targetScale: Int? = decoder.userInfo[.scale] as? Int
			guard let value: Decimals = Decimals(decimal: decimal, scale: targetScale) else {
				throw Decimals.doesNotFit(in: container)
			}
			self = value
			return
		} else

		// google.type.Decimal
		if let dec: GoogleDecimal = try? container.decode(GoogleDecimal.self) {
			let trimmed: String = dec.value.trimmingCharacters(in: .whitespacesAndNewlines)

			if let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(trimmed) {
				guard let value: Decimals = Decimals.fitted(
					mantissa: parsed.units,
					naturalScale: parsed.scale,
					targetScale: nil
				) else {
					throw Decimals.doesNotFit(in: container)
				}
				self = value
				return
			}
		} else

		// String, parse it deterministically (ASCII-only)
		if let raw: String = try? container.decode(String.self) {
			let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)

			if let parsed: (units: Int, scale: Int) = Decimals.parseStringToUnitsScale(trimmed) {
				guard let value: Decimals = Decimals.fitted(
					mantissa: parsed.units,
					naturalScale: parsed.scale,
					targetScale: nil
				) else {
					throw Decimals.doesNotFit(in: container)
				}
				self = value
				return
			}
		} else

		// Object form: {"units":1,"scale":2}
		if let keyed: KeyedDecodingContainer<CodingKeys> = try? decoder.container(keyedBy: CodingKeys.self) {
			let units: Int = try Decimals.decodeField(.units, in: keyed)
			let scale: Int = try Decimals.decodeField(.scale, in: keyed)

			// Int.min has no positive twin: abs, format and decimal break on it.
			guard units != .min else {
				throw DecodingError.dataCorruptedError(
					forKey: .units,
					in: keyed,
					debugDescription: "Units must not be Int.min"
				)
			}
			guard scale >= -Decimals.maxScale, scale <= Decimals.maxScale else {
				throw DecodingError.dataCorruptedError(
					forKey: .scale,
					in: keyed,
					debugDescription: "Scale must be in -18...18"
				)
			}
			// With a negative scale, description writes units * 10^|scale| as Int.
			if scale < 0, units.multipliedReportingOverflow(by: Int.p10[-scale]).overflow {
				throw DecodingError.dataCorruptedError(
					forKey: .units,
					in: keyed,
					debugDescription: "Units * 10^|scale| does not fit into Int"
				)
			}
			self.units = units
			self.scale = scale
			return
		}
		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected decimal number")
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

	/// Multiplies by a rational factor `numerator / denominator` using banker's rounding.
	///
	/// - Parameters:
	///   - numerator: Numerator of the ratio.
	///   - denominator: Denominator of the ratio; must be non-zero.
	/// - Returns: Product with the same `scale`.
	/// - Precondition: Multiplier must be non-negative; no overflow.
	@inline(__always)
	public func multiply(_ numerator: Int, over denominator: Int) -> Decimals {
		precondition(denominator != 0, "Division must be not equal zero in multiply(_:over:)")

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

		if scale < 0 {
			let absScale: Int = -scale
			let multiplier: Int = Int.pow10(scale: absScale)

			// number = magnitude * 10^absScale, pure integer without fraction
			let (intPart, overflow) = magnitude.multipliedReportingOverflow(by: multiplier)
			precondition(!overflow, "Overflow in format() for negative scale")

			// дальше — как сейчас, но с scaleEffective = 0 и fracPart = 0
			let intDigits: Int = intPart == 0 ? 1 : Decimals.digits(intPart)
			let groups: Int = groupSeparator != nil ? max(0, (intDigits - 1) / 3) : 0
			let signWidth: Int = isNegative ? 1 : 0
			let capacity: Int = signWidth + intDigits + groups

			return String(unsafeUninitializedCapacity: capacity, initializingUTF8With: { (buf: UnsafeMutableBufferPointer<UInt8>) -> Int in
				var idx: Int = capacity

				func write(_ byte: UInt8) {
					idx &-= 1
					buf[idx] = byte
				}

				// Only the whole part with the grouping
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

	/// Truncates the price to the nearest tick towards zero.
	/// For positive values this is equivalent to rounding down to the nearest tick.
	///
	/// - Parameter minStep: Tick size in the same `price.scale` (minor units). Must be > 0.
	/// - Returns: Rounded price.
	/// - Precondition: `minStep > 0`.
	@inline(__always)
	public func roundPrice(for minStep: Decimals) -> Decimals {
		precondition(minStep.units > 0, "minStep must be > 0")
		let unit: Int = units >= 0 ? units : -units
		let tick: Int = minStep.units

		let div: Int = unit / tick
		if units >= 0 {
			return .init(units: div &* tick, scale: scale)
		}
		return .init(units: -div &* tick, scale: scale)
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

	// MARK: - Values from outside

	/// Reads the integer mantissa and the natural scale of a `Decimal` on this platform.
	///
	/// - Parameter decimal: The source value.
	/// - Returns: The mantissa and the natural scale (zero or more), or `nil` for NaN and for a
	///   mantissa outside `-Int.max...Int.max`.
	@inline(__always)
	static func parts(of decimal: Decimal) -> (mantissa: Int, scale: Int)? {
#if os(Linux)
		return textParts(of: decimal)
#else
		return storedParts(of: decimal)
#endif
	}

	/// Reads the mantissa and the natural scale from `Decimal.description`.
	///
	/// Linux uses it: swift-corelibs-foundation keeps the storage fields of `Decimal` internal.
	/// The description is locale-independent, has a dot and no exponent. The function is built
	/// on every platform, so the tests on macOS can check the way Linux goes.
	///
	/// - Parameter decimal: The source value.
	/// - Returns: The mantissa and the natural scale, or `nil` for NaN (its description is
	///   "NaN") and for a mantissa outside `-Int.max...Int.max`.
	static func textParts(of decimal: Decimal) -> (mantissa: Int, scale: Int)? {
		let text: String = decimal.description
		guard let parsed: (units: Int, scale: Int) = parseStringToUnitsScale(text) else {
			return nil
		}
		return (parsed.units, parsed.scale)
	}

#if !os(Linux)
	/// Reads the mantissa and the natural scale from the storage fields of `Decimal`.
	///
	/// - Parameter decimal: The source value.
	/// - Returns: The mantissa and the natural scale, or `nil` for NaN, for a mantissa outside
	///   `-Int.max...Int.max` and for a positive exponent that does not fit.
	static func storedParts(of decimal: Decimal) -> (mantissa: Int, scale: Int)? {
		// NaN has length 0, so the code below would read it as zero.
		guard decimal.isFinite else {
			return nil
		}
		// Four 16-bit words are 64 bits. A longer mantissa does not fit into Int.
		let length: Int = Int(decimal._length)
		guard length <= 4 else {
			return nil
		}
		// Collect the magnitude from the little-endian 16-bit words.
		let chunks: [UInt16] = [
			decimal._mantissa.0, decimal._mantissa.1, decimal._mantissa.2, decimal._mantissa.3,
		]
		var magnitude: UInt64 = 0
		for index in 0..<length {
			magnitude |= UInt64(chunks[index]) << UInt64(index * 16)
		}
		// The magnitude stops at Int.max, so Int.min never comes out.
		guard magnitude <= UInt64(Int.max) else {
			return nil
		}
		var mantissa: Int = Int(magnitude)
		let exponent: Int = Int(decimal._exponent)
		var naturalScale: Int = 0

		if exponent < 0 {
			naturalScale = -exponent
		} else if exponent > 0, mantissa != 0 {
			// A positive exponent means trailing zeros that the mantissa does not keep.
			guard exponent <= maxScale else {
				return nil
			}
			let (product, overflow): (Int, Bool) = mantissa.multipliedReportingOverflow(
				by: Int.p10[exponent]
			)
			guard !overflow else {
				return nil
			}
			mantissa = product
		}
		if decimal.isSignMinus {
			mantissa = -mantissa
		}
		return (mantissa, naturalScale)
	}
#endif

	/// Applies the rules for a value from outside to a mantissa and its natural scale.
	///
	/// Zero always fits. With a target scale the value is rounded to it half to even.
	///
	/// - Parameters:
	///   - mantissa: Integer mantissa in `-Int.max...Int.max`.
	///   - naturalScale: Number of fractional digits of the mantissa, zero or more.
	///   - target: The scale of the result, or `nil` to keep the natural scale.
	/// - Returns: The value, or `nil` when it does not fit.
	static func fitted(mantissa: Int, naturalScale: Int, targetScale target: Int?) -> Decimals? {
		if let target, (target < -maxScale || target > maxScale) {
			return nil
		}
		if mantissa == 0 {
			// Zero has no digits to lose, so any exponent gives zero.
			let scale: Int = target ?? (naturalScale <= maxScale ? naturalScale : 0)
			return Decimals(units: 0, scale: scale)
		}
		guard let target else {
			guard naturalScale <= maxScale else {
				return nil
			}
			return Decimals(units: mantissa, scale: naturalScale)
		}
		// The exponent of a Decimal is -128...127, so the difference cannot overflow.
		guard let units: Int = mantissa.pow10Checked(target - naturalScale) else {
			return nil
		}
		return Decimals(units: units, scale: target)
	}

	/// Makes the error for a number that is valid but does not fit into `Decimals`.
	///
	/// - Parameter container: The container of the value; its path goes into the error.
	/// - Returns: `DecodingError.dataCorrupted` with the path of the field.
	private static func doesNotFit(
		in container: any SingleValueDecodingContainer
	) -> DecodingError {
		return DecodingError.dataCorruptedError(
			in: container,
			debugDescription: "Number does not fit into Decimals"
		)
	}

	/// Reads one integer field of the object form.
	///
	/// A missing key stays `keyNotFound`. Any other error becomes `dataCorrupted` with the key
	/// in its path: Foundation gives such an error without the path, and on Linux without
	/// the reason.
	///
	/// - Parameters:
	///   - key: The field to read.
	///   - keyed: The container of the object.
	/// - Returns: The value of the field.
	/// - Throws: `DecodingError.keyNotFound` or `DecodingError.dataCorrupted`.
	private static func decodeField(
		_ key: CodingKeys,
		in keyed: KeyedDecodingContainer<CodingKeys>
	) throws -> Int {
		do {
			return try keyed.decode(Int.self, forKey: key)
		} catch DecodingError.keyNotFound(let missing, let context) {
			throw DecodingError.keyNotFound(missing, context)
		} catch {
			throw DecodingError.dataCorruptedError(
				forKey: key,
				in: keyed,
				debugDescription: "Expected an integer that fits into Int"
			)
		}
	}

	/// Parses ASCII decimal string into `(units, scale)` pair.
	///
	/// Accepted forms: optional sign ('+' or '-'), decimal mantissa, optional exponent 'e' or 'E'.
	/// The mantissa may omit integer digits before '.' or ',', but a separator requires fractional digits.
	/// Examples: "123", "-123.45", ".5", "-,001", "1.23e2", "-1.2E-3". Grouping separators are NOT supported.
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
				// Integer digits are optional; only one separator is allowed.
				if sawSeparator {
					return nil
				}
				begin = false
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
					// accumulate mantissa absolute units: unitsAbs = unitsAbs * 10 + digit
					let (tmp, of1) = unitsAbs.multipliedReportingOverflow(by: 10)
					if of1 { return nil }

					let (tmp2, of2) = tmp.addingReportingOverflow(digit)
					if of2 { return nil }

					unitsAbs = tmp2

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
					// A shift above 18 fits only for zero: any other mantissa overflows.
					if shift > maxScale {
						if units != 0 {
							return nil
						}
						return (0, 0)
					}
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
