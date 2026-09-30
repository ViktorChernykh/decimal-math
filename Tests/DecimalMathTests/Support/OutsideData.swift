import Foundation
@testable import DecimalMath

/// A model like the ones the apps decode: the price sits in an array of items.
struct PriceBox: Decodable {
	struct Item: Decodable {
		let price: Decimals
	}

	let items: [Item]
}

/// Helpers for the tests of values that come from outside the program.
enum OutsideData {
	/// The path of the price field in `PriceBox`.
	static let pricePath: String = "items.0.price"

	/// Decodes `{"items":[{"price":<json>}]}` as the apps do.
	///
	/// - Parameters:
	///   - json: The JSON text of the price.
	///   - scale: The value of `userInfo[.scale]`, or `nil` for no key.
	/// - Returns: The decoded price.
	/// - Throws: The error of `JSONDecoder`.
	static func decode(_ json: String, scale: Int? = nil) throws -> Decimals {
		let decoder: JSONDecoder = .init()
		if let scale {
			decoder.userInfo = [.scale: scale]
		}
		let data: Data = Data(#"{"items":[{"price":\#(json)}]}"#.utf8)

		return try decoder.decode(PriceBox.self, from: data).items[0].price
	}

	/// Decodes the price and describes the result for an expectation.
	///
	/// - Parameters:
	///   - json: The JSON text of the price.
	///   - scale: The value of `userInfo[.scale]`, or `nil` for no key.
	/// - Returns: "corrupted at <path>" for `DecodingError.dataCorrupted`,
	///   "value <units> <scale>" for a value, or the text of another error.
	static func outcome(_ json: String, scale: Int? = nil) -> String {
		do {
			let value: Decimals = try decode(json, scale: scale)
			return "value \(value.units) \(value.scale)"
		} catch DecodingError.dataCorrupted(let context) {
			return "corrupted at \(path(context.codingPath))"
		} catch DecodingError.keyNotFound(let key, _) {
			return "key not found \(key.stringValue)"
		} catch {
			return "other error \(error)"
		}
	}

	/// Describes a value the same way as `outcome(_:scale:)`.
	///
	/// - Parameter value: The value, or `nil`.
	/// - Returns: "value <units> <scale>" or "nil".
	static func describe(_ value: Decimals?) -> String {
		guard let value else {
			return "nil"
		}
		return "value \(value.units) \(value.scale)"
	}

	/// Joins a coding path into text like "items.0.price".
	///
	/// - Parameter codingPath: The path of an error.
	/// - Returns: The keys joined by dots; an index is written as its number.
	static func path(_ codingPath: [any CodingKey]) -> String {
		codingPath
			.map { (key: any CodingKey) -> String in
				key.intValue.map { String($0) } ?? key.stringValue
			}
			.joined(separator: ".")
	}
}
