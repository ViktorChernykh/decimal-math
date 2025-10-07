# DecimalMath

**DecimalMath** is a Swift library for robust, efficient, and integer-accurate decimal fixed-point arithmetic—ideal for finance, trading, accounting, or any use case where rounding errors from floating-point math are unacceptable.

- 📦 **Platforms:** iOS 17+, macOS 14+
- 🧮 **Precision:** All calculations use integer math with explicit decimal scales, ensuring predictable, lossless results.
- 🪙 **Use cases:** Money, quantities, prices, rounding, lots/ticks, proportional allocation, and more.

---

## Features

- **`Decimals` type:** Immutable integer-based fixed-point decimal with configurable scale
- **Safe integer math:** No floating-point conversion or rounding surprises
- **Banker's rounding:** Standard "round half to even" where needed
- **Rounding utilities:** Lot size, tick size, and price rounding with custom modes
- **Proportional allocation:** Split or allocate values exactly, using the Largest Remainder Method
- **Formatting:** High-performance ASCII output for reporting
- **VWAP, notional, and price-adjustment helpers**
- **Swift Concurrency, Sendable and Hashable ready**
- **JSON encoding/decoding:** Seamless integration with `Codable` — `Decimals` can decode from `Double` and encode back to `Double` for compact JSON representation

---

## Installation

### Swift Package Manager

In Xcode or in your `Package.swift`:

```swift
.package(url: "https://github.com/your-org/decimal-math.git", from: "0.1.0"),
```
