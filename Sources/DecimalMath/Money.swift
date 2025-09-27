//
//  Money.swift
//  DecimalMath
//
//  Created by Victor Chernykh on 22.09.2025.
//

public struct Money: Sendable, Hashable {
	public let amount: Decimals
	public let currency: String

	/// Creates a money value aligned to the currency's default minor units (ISO 4217).
	///
	/// - Parameters:
	///   - amount: Integer amount with an explicit decimal `scale`.
	///   - currency: ISO 4217 currency code (case-insensitive). The `amount` will be rescaled to this currency's default scale if needed.
	/// - Precondition: Rescaling must not overflow and the currency scale must be supported.
	@inline(__always)
	public init(amount: Decimals, currency: String) {
		self.currency = currency
		let scale: Int = Money.defaultMinorUnits[currency.uppercased()] ?? 2
		if amount.scale == scale {
			self.amount = amount
		} else {
			self.amount = amount.rescaled(to: scale)
		}
	}

	// MARK: ISO 4217 scale

	/// Resolves minor-units (fractional digits) for an ISO 4217 currency code.
	///
	/// - Parameter currencyCode: ISO 4217 code (e.g., "RUB", "USD"). Case-insensitive.
	/// - Returns: Number of fractional digits; defaults to 2 if unknown.
	@inline(__always)
	public static func scale(for currencyCode: String) -> Int {
		return defaultMinorUnits[currencyCode.uppercased()] ?? 2
	}

	private static let defaultMinorUnits: [String: Int] = [
		"USD": 2, "EUR": 2, "RUB": 2, "GBP": 2, "CHF": 2, "CNY": 2,
		"JPY": 0, "KRW": 0, "KWD": 3, "BHD": 3, "CLP": 0,
		// Cryptocurrencies
		"BTC": 8,   // Satoshi
		"ETH": 18,  // wei → 10^18
		"USDT": 6,  // Tether (often 6 characters)
		"USDC": 6,  // USD Coin
		"BNB": 18,  // Binance Coin
		"SOL": 9,   // Solana
		"XRP": 6,
		"ADA": 6,
		"DOGE": 8,
		"DOT": 10
	]

	/// Converts this money amount to another currency using a rational FX rate (quote per 1 base).
	///
	/// - Parameters:
	///   - quoteCurrency: Target ISO 4217 currency code.
	///   - numerator: FX rate numerator (must be non-negative).
	///   - denominator: FX rate denominator; must be > 0.
	/// - Returns: Converted money in `quoteCurrency`, rounded with banker's rounding at the target scale.
	/// - Precondition: Rescaling and arithmetic must not overflow; `denominator` must be > 0.
	@inline(__always)
	public func convert(to quoteCurrency: String, numerator: Int, denominator: Int) -> Money {
		let targetScale: Int = Money.scale(for: quoteCurrency.uppercased())
		let base: Decimals = amount.rescaled(to: targetScale)
		let converted: Decimals = base.multiply(numerator, over: denominator)

		return Money(amount: converted, currency: quoteCurrency)
	}
}
