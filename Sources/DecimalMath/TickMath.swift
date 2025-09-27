//
//  TickMath.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

public enum TickMath {

	/// Rounds a price to the nearest tick according to the rounding mode.
	/// 
	/// - Parameters:
	///   - price: Price in `Decimals` (money per 1 base unit).
	///   - tick: Tick size in the same `price.scale` (minor units). Must be > 0.
	///   - mode: Rounding mode.
	/// - Returns: Rounded price.
	/// - Precondition: `tick > 0`.
	@inline(__always)
	public static func roundPrice(
		_ price: Decimals,
		tick: Int,
		mode: StepRounding
	) -> Decimals {
		precondition(tick > 0, "tick must be > 0")
		let units: Int = price.units
		switch mode {
		case .floor:
			let div: Int = units / tick
			let rem: Int = units % tick
			if units >= 0 || rem == 0 {
				return .init(units: div &* tick, scale: price.scale)
			}
			return .init(units: (div &- 1) &* tick, scale: price.scale)
		case .ceil:
			let div: Int = units / tick
			let rem: Int = units % tick
			if rem == 0 || units <= 0 {
				return .init(units: div &* tick, scale: price.scale)
			}
			return .init(units: (div &+ 1) &* tick, scale: price.scale)
		case .nearest:
			let div: Int = units / tick
			let rem: Int = units % tick
			if rem == 0 {
				return .init(units: div &* tick, scale: price.scale)
			}
			let absR: Int = rem >= 0 ? rem : -rem
			let half: Int = tick / 2
			let isHalf: Bool = (tick % 2 == 0) && (absR == half)
			let shouldUp: Bool = isHalf ? ((div & 1) != 0) : (absR > half)
			if !shouldUp {
				return .init(units: div &* tick, scale: price.scale)
			} else {
				let adjusted: Int = rem >= 0 ? (div &+ 1) : (div &- 1)
				return .init(units: adjusted &* tick, scale: price.scale)
			}
		}
	}
}
