//
//  BinaryFunctions.swift
//  decimal-math
//
//  Created by Victor Chernykh on 21.10.2025.
//

/// Adds two fixed-point values, preserving left `scale` (banker's rounding if downscaling RHS).
@inline(__always)
public func + (_ lhs: Decimals, _ rhs: Decimals) -> Decimals {
	let right: Decimals = rhs.rescaled(to: lhs.scale)
	return Decimals(units: lhs.units &+ right.units, scale: lhs.scale)
}

/// Subtracts another fixed-point value, preserving left `scale` (banker's rounding if downscaling RHS).
@inline(__always)
public func - (_ lhs: Decimals, _ rhs: Decimals) -> Decimals {
	let right: Decimals = rhs.rescaled(to: lhs.scale)
	return Decimals(units: lhs.units &- right.units, scale: lhs.scale)
}

/// Multiplies two fixed-point values using banker's rounding, preserving left `scale`.
@inline(__always)
public func * (_ lhs: Decimals, _ rhs: Decimals) -> Decimals {
	// Raw product has scale = lhs.scale + rhs.scale.
	let rawUnits: Int = lhs.units &* rhs.units
	let targetScale: Int = lhs.scale
	let rawScale: Int = lhs.scale &+ rhs.scale

	if rawScale == targetScale {
		return Decimals(units: rawUnits, scale: targetScale)
	} else if rawScale > targetScale {
		// Need to downscale with half-to-even by delta = rawScale - targetScale.
		let delta: Int = rawScale &- targetScale
		let divisor: Int = Int.pow10(scale: delta)
		// q/r in integer domain, then banker's rounding.
		let q: Int = rawUnits / divisor
		let r: Int = rawUnits % divisor
		let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: divisor)
		return Decimals(units: rounded, scale: targetScale)
	} else {
		// Need to upscale: multiply by 10^(target - raw)
		let delta: Int = targetScale &- rawScale
		let multiplier: Int = Int.pow10(scale: delta)
		let up: Int = rawUnits &* multiplier
		return Decimals(units: up, scale: targetScale)
	}
}

/// Multiplies by an integer factor, preserving left `scale`.
@inline(__always)
public func * (_ lhs: Decimals, _ rhs: Int) -> Decimals {
	Decimals(units: lhs.units &* rhs, scale: lhs.scale)
}

/// Divides by an integer divisor using banker's rounding, preserving left `scale`.
@inline(__always)
public func / (_ lhs: Decimals, _ rhs: Decimals) -> Decimals {
	// Compute (lhs.units * 10^rhs.scale) / rhs.units with half-to-even.
	precondition(rhs.units != 0, "Division by zero in Decimals / Decimals")
	let factor: Int = Int.pow10(scale: rhs.scale)
	let numerator: Int = lhs.units &* factor
	let denominator: Int = rhs.units
	let q: Int = numerator / denominator
	let r: Int = numerator % denominator
	let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: denominator > 0 ? denominator : -denominator)
	return Decimals(units: rounded, scale: lhs.scale)
}

/// Divides by an integer divisor using banker's rounding, preserving left `scale`.
@inline(__always)
public func / (_ lhs: Decimals, _ rhs: Int) -> Decimals {
	precondition(rhs != 0, "Division by zero in Decimals / Int")
	let divisor: Int = rhs > 0 ? rhs : -rhs
	let numerator: Int = lhs.units > 0 ? lhs.units : -lhs.units
	let q: Int = numerator / divisor
	let r: Int = numerator % divisor
	let rounded: Int = Decimals.roundHalfToEven(quotient: q, remainder: r, divisor: divisor)
	// Sign of divisor handled by quotient/remainder rules already.
	return Decimals(units: lhs.units * rhs >= 0 ? rounded : -rounded, scale: lhs.scale)
}


@inline(__always)
public func == (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units == rhs.units
	} else {
		let right: Decimals = rhs.rescaled(to: lhs.scale)
		return lhs.units == right.units
	}
}


@inline(__always)
public func != (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units != rhs.units
	} else {
		let scale: Int = max(lhs.scale, rhs.scale)
		let left: Decimals = lhs.rescaled(to: scale)
		let right: Decimals = rhs.rescaled(to: scale)
		return left.units != right.units
	}
}


@inline(__always)
public func > (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units > rhs.units
	} else {
		let scale: Int = max(lhs.scale, rhs.scale)
		let left: Decimals = lhs.rescaled(to: scale)
		let right: Decimals = rhs.rescaled(to: scale)
		return left.units > right.units
	}
}


@inline(__always)
public func < (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units < rhs.units
	} else {
		let scale: Int = max(lhs.scale, rhs.scale)
		let left: Decimals = lhs.rescaled(to: scale)
		let right: Decimals = rhs.rescaled(to: scale)
		return left.units < right.units
	}
}


@inline(__always)
public func >= (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units >= rhs.units
	} else {
		let scale: Int = max(lhs.scale, rhs.scale)
		let left: Decimals = lhs.rescaled(to: scale)
		let right: Decimals = rhs.rescaled(to: scale)
		return left.units >= right.units
	}
}


@inline(__always)
public func <= (_ lhs: Decimals, _ rhs: Decimals) -> Bool {
	if lhs.scale == rhs.scale {
		return lhs.units <= rhs.units
	} else {
		let scale: Int = max(lhs.scale, rhs.scale)
		let left: Decimals = lhs.rescaled(to: scale)
		let right: Decimals = rhs.rescaled(to: scale)
		return left.units <= right.units
	}
}
