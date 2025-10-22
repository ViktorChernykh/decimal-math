//
//  QuantityMath.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

public enum QuantityMath {

	// MARK: Lot rounding

	/// Rounds a quantity to the nearest lot boundary according to the rounding mode.
	///
	/// - Parameters:
	///   - quantity: Quantity to round.
	///   - lotSize: Lot size expressed at the same `quantity.scale`. Must be > 0 in *minor units*.
	///   - mode: Rounding mode (floor/ceil/nearest).
	/// - Returns: Quantity aligned to lot.
	/// - Preconditions: `lotSize > 0`.
	@inline(__always)
	public static func roundToLot(
		_ quantity: Decimals,
		lotSize: Int,
		mode: StepRounding
	) -> Decimals {
		precondition(lotSize > 0, "lotSize must be > 0")
		let q: Int = quantity.units
		switch mode {
		case .floor:
			// Works for negatives as well (Swift truncates toward zero; emulate floor)
			let div: Int = q / lotSize
			let rem: Int = q % lotSize
			if rem == 0 || q >= 0 {
				return .init(units: div * lotSize, scale: quantity.scale)
			}
			return .init(units: (div - 1) * lotSize, scale: quantity.scale)
		case .ceil:
			let div: Int = q / lotSize
			let rem: Int = q % lotSize
			if rem == 0 || q <= 0 {
				return .init(units: div * lotSize, scale: quantity.scale)
			}
			return .init(units: (div + 1) * lotSize, scale: quantity.scale)
		case .nearest:
			// Banker's rounding to the closest lot boundary
			let div: Int = q / lotSize
			let rem: Int = q % lotSize
			if rem == 0 {
				return .init(units: div * lotSize, scale: quantity.scale)
			}
			let absR: Int = rem >= 0 ? rem : -rem
			let half: Int = lotSize / 2
			let isHalf: Bool = (lotSize % 2 == 0) && (absR == half)
			let shouldUp: Bool = isHalf ? ((div & 1) != 0) : (absR > half)
			if !shouldUp {
				// round towards zero
				return .init(units: div * lotSize, scale: quantity.scale)
			} else {
				// round away from zero based on remainder sign
				let adjusted: Int = rem >= 0 ? (div + 1) : (div - 1)
				return .init(units: adjusted * lotSize, scale: quantity.scale)
			}
		}
	}

	/// Clamps a quantity to inclusive bounds (same scale).
	///
	/// - Parameters:
	///   - quantity: Value to clamp.
	///   - min: Minimum inclusive bound (same scale).
	///   - max: Maximum inclusive bound (same scale).
	/// - Returns: Clamped quantity.
	/// - Preconditions: `min.scale == max.scale == quantity.scale` and `min <= max`.
	@inline(__always)
	public static func clamp(
		_ quantity: Decimals,
		min: Decimals,
		max: Decimals
	) -> Decimals {
		precondition(quantity.scale == min.scale && min.scale == max.scale, "Scale mismatch in clamp")
		precondition(min.units <= max.units, "Invalid bounds in clamp")
		if quantity.units < min.units {
			return min
		}
		if quantity.units > max.units {
			return max
		}
		return quantity
	}

	// MARK: Tick rounding for prices

	/// Rounds a price to the nearest tick according to the rounding mode.
	///
	/// - Parameters:
	///   - price: Price in `Decimals` (money per 1 base quantity).
	///   - tick: Tick size in the same `price.scale` (minor units!). Must be > 0.
	///   - mode: Rounding mode.
	/// - Returns: Rounded price.
	/// - Preconditions: `tick > 0`.
	@inline(__always)
	public static func roundToTick(
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
				return .init(units: div * tick, scale: price.scale)
			}
			return .init(units: (div - 1) * tick, scale: price.scale)
		case .ceil:
			let div: Int = units / tick
			let rem: Int = units % tick
			if rem == 0 || units <= 0 {
				return .init(units: div * tick, scale: price.scale)
			}
			return .init(units: (div + 1) * tick, scale: price.scale)
		case .nearest:
			let div: Int = units / tick
			let rem: Int = units % tick
			if rem == 0 {
				return .init(units: div * tick, scale: price.scale)
			}
			let absR: Int = rem >= 0 ? rem : -rem
			let half: Int = tick / 2
			let isHalf: Bool = (tick % 2 == 0) && (absR == half)
			let shouldUp: Bool = isHalf ? ((div & 1) != 0) : (absR > half)
			if !shouldUp {
				return .init(units: div * tick, scale: price.scale)
			} else {
				let adjusted: Int = rem >= 0 ? (div + 1) : (div - 1)
				return .init(units: adjusted * tick, scale: price.scale)
			}
		}
	}

	// MARK: Notional (price × quantity)

	/// Computes money notional: `price * quantity`.
	///
	/// - Parameters:
	///   - price: Money per 1 base quantity (`Decimals`).
	///   - quantity: Fixed-point quantity.
	/// - Returns: Notional `Decimals` in the same scale/currency as `price`.
	/// - Discussion: Uses exact integer rational: `price * quantity.units / 10^quantity.scale` with banker's rounding.
	@inline(__always)
	public static func notional(price: Decimals, quantity: Decimals) -> Decimals {
		let den: Int = Int.pow10(scale: quantity.scale)
		return price.multiply(quantity.units, over: den)
	}

	/// Computes volume-weighted average price (VWAP) for a set of fills.
	///
	/// - Parameter fills: Array of `(quantity, price)` pairs.
	/// - Returns: VWAP in the same scale as `price`.
	/// - Preconditions: Non-empty `fills`; all prices share the same scale.
	@inline(__always)
	public static func vwap(fills: [(quantity: Decimals, price: Decimals)]) -> Decimals {
		precondition(!fills.isEmpty, "fills must be non-empty")
		let targetScale: Int = fills[0].price.scale
		var totalNotional: Decimals = .init(units: 0, scale: targetScale)
		var totalBaseUnits: Int = 0
		for (q, p) in fills {
			precondition(p.scale == targetScale, "Price scale mismatch in vwap")
			totalNotional = totalNotional + notional(price: p, quantity: q)
			let (s, of) = totalBaseUnits.addingReportingOverflow(q.units)
			precondition(!of, "Overflow in vwap total quantity")
			totalBaseUnits = s
		}
		precondition(totalBaseUnits != 0, "Total quantity must not be zero in vwap")
		// price = notional / (quantity in base units)
		// totalBaseUnits are at quantity.scale; to get “per 1 base unit”, divide by 10^scale.
		let den: Int = Int.pow10(scale: fills[0].quantity.scale)
		// notional / (totalBaseUnits / den) == notional * den / totalBaseUnits
		let scaled: Decimals = totalNotional.multiply(den, over: totalBaseUnits)
		return scaled
	}

	// MARK: Price adjustments (bps / percent)

	/// Applies basis points (bps) to price: `price * (1 + bps/10_000)`.
	///
	/// - Parameters:
	///   - price: Base price.
	///   - bps: Basis points (can be negative).
	/// - Returns: Adjusted price in the same scale.
	@inline(__always)
	public static func applyBps(_ price: Decimals, bps: Int) -> Decimals {
		// 1 + bps/10_000 = (10_000 + bps) / 10_000
		let num: Int = 10_000 &+ bps
		let den: Int = 10_000
		if num >= 0 {
			return price.multiply(num, over: den)
		} else {
			// For negative numerator we reflect sign through `Decimals.multiply` contract (expects non-negative numerator).
			// price * (-k/den) == -(price * (k/den))
			let pos: Int = -num
			let adj: Decimals = price.multiply(pos, over: den)
			return .init(units: -adj.units, scale: adj.scale)
		}
	}

	/// Applies percentage change to price: `price * (1 + pctNum/pctDen)`.
	///
	/// - Parameters:
	///   - price: Base price.
	///   - pctNumerator: Signed numerator of percentage (e.g., +15 for +15/100).
	///   - pctDenominator: Denominator (e.g., 100 for percent, 10_000 for bp).
	/// - Returns: Adjusted price.
	@inline(__always)
	public static func applyRatio(
		_ price: Decimals,
		pctNumerator: Int,
		pctDenominator: Int
	) -> Decimals {
		precondition(pctDenominator > 0, "pctDenominator must be > 0")
		let num: Int = pctDenominator &+ pctNumerator
		if num >= 0 {
			return price.multiply(num, over: pctDenominator)
		} else {
			let pos: Int = -num
			let adj: Decimals = price.multiply(pos, over: pctDenominator)
			return .init(units: -adj.units, scale: adj.scale)
		}
	}

	// MARK: Budgeted buy amount

	/// Computes the maximum buy quantity under a cash budget, considering price, lot size and optional fee in bps.
	///
	/// - Parameters:
	///   - budget: Cash budget (`Decimals`) including fees.
	///   - unitPrice: Price per 1 base unit (`Decimals`).
	///   - quantityScale: Desired quantity scale for result.
	///   - lotSize: Optional lot size (in minor units at `quantityScale`). If `nil`, lot is 1 minor unit.
	///   - feeBps: Optional fee in basis points applied to notional (e.g., 15 → 0.15%). Default 0.
	/// - Returns: Quantity not exceeding `budget`, aligned to `lotSize`.
	/// - Discussion: Computes inverse of `notional(price, quantity) * (1 + fee) <= budget`.
	@inline(__always)
	public static func maxBuyQuantity(
		budget: Decimals,
		unitPrice: Decimals,
		quantityScale: Int,
		lotSize: Int? = nil,
		feeBps: Int = 0
	) -> Decimals {
		precondition(budget.units >= 0, "budget must be non-negative")
		precondition(unitPrice.units > 0, "unitPrice must be positive")
		let lot: Int = lotSize ?? 1
		precondition(lot > 0, "lotSize must be > 0")

		// Effective price with fee: price * (1 + feeBps/10_000)
		let effectivePrice: Decimals = applyBps(unitPrice, bps: feeBps)

		// We want max q such that: effectivePrice * q/10^quantityScale <= budget
		// → q <= budget * 10^quantityScale / effectivePrice
		let scaleFactor: Int = Int.pow10(scale: quantityScale)

		// qty = (budget * scaleFactor / effectivePrice)
		//	.rescaled(to: quantityScale)
		let tmp: Decimals = budget * scaleFactor
		var qty: Decimals = (tmp / effectivePrice).rescaled(to: quantityScale)

		if lot > 1 {
			qty = roundToLot(qty, lotSize: lot, mode: .floor)
		}
		if qty.units < 0 {
			qty = .init(units: 0, scale: quantityScale)
		}
		return qty
	}
}
