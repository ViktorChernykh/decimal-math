import Foundation
import Testing
@testable import DecimalMath

/// Tests for `Decimals.encode(to:)` JSON encoding behavior.
@Suite("Decimals JSON Encoding")
struct DecimalsEncodingTests {
	/// Helper: encodes a value to a UTF-8 JSON string.
	/// - Returns: Compact JSON string (e.g., 123.45)
	private func encodeJSONString(_ value: Decimals, encoder: JSONEncoder = .init()) throws -> String {
		let data: Data = try encoder.encode(value)
		guard let json: String = String(data: data, encoding: .utf8) else {
			#expect(Bool(false), "Failed to build UTF-8 string from encoded JSON")
			return ""
		}
		return json
	}

	@Test("Encodes as a plain JSON number (not quoted, not an object)")
	func encodesAsPlainNumber() throws {
		let value: Decimals = .init(units: 12345, scale: 2)
		let json: String = try encodeJSONString(value)

		// Ensure it is not a string literal and not a JSON object/array
		#expect(!json.contains("\""), "Encoded value must not be quoted")
		if let first: Character = json.first {
			#expect(first != "{" && first != "[", "Encoded value must be a numeric literal, got: \(json)")
		}
	}

	@Test("Encodes positive value with scale=2 correctly")
	func encodesPositiveScale2() throws {
		let value: Decimals = .init(units: 12345, scale: 2) // 123.45
		let encoder: JSONEncoder = .init()
		let data: Data = try encoder.encode(value)
		let decoded: Double = try JSONDecoder().decode(Double.self, from: data)
		#expect(abs(decoded - 123.45) < 1e-12, "Expected 123.45, got: \(decoded)")
	}

	@Test("Encodes negative integral value (scale=0)")
	func encodesNegativeIntegral() throws {
		let value: Decimals = .init(units: -5, scale: 0)
		let data: Data = try JSONEncoder().encode(value)
		let decoded: Double = try JSONDecoder().decode(Double.self, from: data)
		#expect(decoded == -5.0)
	}

	@Test("Encodes zero consistently across scales")
	func encodesZeroAnyScale() throws {
		for s in 0...6 {
			let value: Decimals = .init(units: 0, scale: s)
			let data: Data = try JSONEncoder().encode(value)
			let decoded: Double = try JSONDecoder().decode(Double.self, from: data)
			#expect(decoded == 0.0, "Zero must encode as 0.0 even for scale=\(s)")
		}
	}

	@Test("Encodes small fractional values; accept scientific notation as valid JSON number")
	func encodesSmallFractions() throws {
		let value: Decimals = .init(units: 1, scale: 8) // 0.00000001
		let data: Data = try JSONEncoder().encode(value)
		let decoded: Double = try JSONDecoder().decode(Double.self, from: data)
		#expect(abs(decoded - 0.00000001) < 1e-20)
	}
}
