//
//  StepRounding.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

/// Rounding modes for discrete steps (lot size, tick size).
public enum StepRounding: Sendable {
	/// Round towards negative infinity.
	case floor
	/// Round towards positive infinity.
	case ceil
	/// Round to nearest; exact halves to even.
	case nearest
}
