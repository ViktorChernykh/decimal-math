//
//  LotMath.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

public enum LotMath {

	/// Rounds a *piece count* (quantity) to the nearest lot boundary according to the rounding mode.
	///
	/// - Parameters:
	///   - quantity: Integer count of pieces/contracts (can be negative for shorts).
	///   - lotSize: Lot size in **pieces**. Must be > 0.
	///   - mode: Rounding mode (floor/ceil/nearest).
	/// - Returns: Quantity aligned to lot size (integer).
	/// - Precondition: `lotSize > 0`.
	@inline(__always)
	public static func roundQuantity(
		_ quantity: Int,
		lotSize: Int,
		mode: StepRounding = .floor
	) -> Int {
		precondition(lotSize > 0, "lotSize must be > 0")
		switch mode {
		case .floor:
			// Swift integer division truncates toward zero; emulate floor for negatives.
			let div: Int = quantity / lotSize
			let rem: Int = quantity % lotSize
			if rem == 0 || quantity >= 0 {
				return div &* lotSize
			}
			return (div &- 1) &* lotSize
		case .ceil:
			let div: Int = quantity / lotSize
			let rem: Int = quantity % lotSize
			if rem == 0 || quantity <= 0 {
				return div &* lotSize
			}
			return (div &+ 1) &* lotSize
		case .nearest:
			let div: Int = quantity / lotSize
			let rem: Int = quantity % lotSize
			if rem == 0 {
				return div &* lotSize
			}
			let absR: Int = rem >= 0 ? rem : -rem
			let half: Int = lotSize / 2
			let isHalf: Bool = (lotSize % 2 == 0) && (absR == half)
			let shouldUp: Bool = isHalf ? (div & 1 != 0) : (absR > half)
			if !shouldUp {
				return div &* lotSize
			} else {
				let adjusted: Int = rem >= 0 ? (div &+ 1) : (div &- 1)
				return adjusted &* lotSize
			}
		}
	}

	/// Clamps an integer quantity to inclusive bounds.
	///
	/// - Parameters:
	///   - quantity: Value to clamp.
	///   - min: Inclusive lower bound.
	///   - max: Inclusive upper bound.
	/// - Returns: Clamped quantity.
	/// - Precondition: `min <= max`.
	@inline(__always)
	public static func clampQuantity(_ quantity: Int, min: Int, max: Int) -> Int {
		precondition(min <= max, "Invalid bounds in clampQuantity")
		if quantity < min {
			return min
		}
		if quantity > max {
			return max
		}
		return quantity
	}
}
