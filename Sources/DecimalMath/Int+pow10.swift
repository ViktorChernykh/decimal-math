//
//  Int+pow10.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

extension Int {
	// MARK: Precomputed powers of 10

	/// Fast Int powers for 0...18 (covers typical money scales).
	public static let p10: [Int] = [
		1,
		10,
		100,
		1_000,
		10_000,
		100_000,
		1_000_000,
		10_000_000,
		100_000_000,
		1_000_000_000,
		10_000_000_000,
		100_000_000_000,
		1_000_000_000_000,
		10_000_000_000_000,
		100_000_000_000_000,
		1_000_000_000_000_000,
		10_000_000_000_000_000,
		100_000_000_000_000_000,
		1_000_000_000_000_000_000, // 10^18
	]

	/// Returns 10 raised to the power of `scale` as an `Int`.
	///
	/// - Parameter scale: Non-negative exponent in the inclusive range supported by `Int.p10` (0...18).
	/// - Returns: The value of 10^`scale`.
	/// - Precondition: `scale` must be in 0...18.
	/// - Note: This is a pure lookup into the precomputed `Int.p10` table.
	public static func pow10(scale: Int) -> Int {
		precondition(scale >= 0 && scale < Int.p10.count, "scale must be 0 <= scale < \(Int.p10.count)")

		return Int.p10[scale]
	}

	/// Multiplies or divides the integer by 10^`scale` with banker's rounding for downscale.
	///
	/// - Parameter scale: Signed scale delta. `scale > 0` multiplies; `scale < 0` divides with banker's rounding; `scale == 0` returns `self`.
	/// - Returns: The rescaled integer.
	/// - Precondition: Absolute value of `scale` must be within the supported range of `Int.p10` (0...18). Multiplication/division must not overflow.
	/// - Discussion: When `scale < 0`, this method computes `q = self / 10^|scale|`
	/// 		   and `r = self % 10^|scale|`
	/// 		   and then applies **round half to even** to `(q, r)`.
	@inline(__always)
	public func pow10(_ scale: Int) -> Int {
		if scale == 0 {
			return self
		}
		let index: Int = scale >= 0 ? scale : -scale
		let multiplier: Int = Int.pow10(scale: index)

		if scale >= 0 {
			let (result, overflow) = self.multipliedReportingOverflow(by: multiplier)
			precondition(!overflow, "Overflow in pow10(_:): \(self) * \(multiplier)")
			return result
		} else {
			let (q, of1) = self.dividedReportingOverflow(by: multiplier)
			precondition(!of1, "Overflow in pow10(_:): \(self) / \(multiplier)")

			let (r, of2) = self.remainderReportingOverflow(dividingBy: multiplier)
			precondition(!of2, "Overflow in pow10(_:): \(self) % \(multiplier)")

			return Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: multiplier)
		}
	}

	/// Multiplies or divides the integer by 10^`scale`, like `pow10(_:)`, but returns `nil`
	/// instead of stopping the process. It is for values that come from outside.
	///
	/// - Parameter scale: Signed scale delta. `scale > 0` multiplies; `scale < 0` divides with
	///   banker's rounding; `scale == 0` returns `self`.
	/// - Returns: The rescaled integer, or `nil` when |`scale`| is above 18 or the
	///   multiplication overflows.
	@inline(__always)
	func pow10Checked(_ scale: Int) -> Int? {
		if scale == 0 {
			return self
		}
		let index: Int = scale >= 0 ? scale : -scale
		guard index < Int.p10.count else {
			return nil
		}
		let multiplier: Int = Int.p10[index]

		if scale > 0 {
			let (result, overflow): (Int, Bool) = self.multipliedReportingOverflow(by: multiplier)
			return overflow ? nil : result
		}
		// A division by 10^k > 0 cannot overflow.
		return Decimals.roundHalfToEven(
			quotient: self / multiplier,
			remainder: self % multiplier,
			divisor: multiplier
		)
	}
}
