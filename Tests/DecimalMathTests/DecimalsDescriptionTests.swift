import Testing
@testable import DecimalMath

@Suite("Decimals.description tests")
struct DecimalsDescriptionTests {

	@Test("Scale = 0 returns plain units string")
	func description_withoutScale() {
		let value1: Decimals = .init(units: 0, scale: 0)
		let value2: Decimals = .init(units: 12345, scale: 0)
		let value3: Decimals = .init(units: -987, scale: 0)

		let result1: String = value1.description
		let result2: String = value2.description
		let result3: String = value3.description

		#expect(result1 == "0")
		#expect(result2 == "12345")
		#expect(result3 == "-987")
	}

	@Test("Simple positive values with fractional scale")
	func description_positiveWithFraction() {
		let value1: Decimals = .init(units: 12345, scale: 2)   // 123.45
		let value2: Decimals = .init(units: 100, scale: 2)     // 1.00
		let value3: Decimals = .init(units: 1200, scale: 3)    // 1.200

		let result1: String = value1.description
		let result2: String = value2.description
		let result3: String = value3.description

		#expect(result1 == "123.45")
		#expect(result2 == "1.00")
		#expect(result3 == "1.200")
	}

	@Test("Values requiring leading zeros before decimal point")
	func description_requiresLeadingZeros() {
		let value1: Decimals = .init(units: 5, scale: 2)    // 0.05
		let value2: Decimals = .init(units: 7, scale: 3)    // 0.007
		let value3: Decimals = .init(units: 1, scale: 1)    // 0.1

		let result1: String = value1.description
		let result2: String = value2.description
		let result3: String = value3.description

		#expect(result1 == "0.05")
		#expect(result2 == "0.007")
		#expect(result3 == "0.1")
	}

	@Test("Negative values with fractional scale and leading zeros")
	func description_negativeValues() {
		let value1: Decimals = .init(units: -5, scale: 2)    // -0.05
		let value2: Decimals = .init(units: -7, scale: 3)    // -0.007
		let value3: Decimals = .init(units: -12345, scale: 2) // -123.45

		let result1: String = value1.description
		let result2: String = value2.description
		let result3: String = value3.description

		#expect(result1 == "-0.05")
		#expect(result2 == "-0.007")
		#expect(result3 == "-123.45")
	}

	@Test("Digits count larger than scale")
	func description_digitsGreaterThanScale() {
		let value1: Decimals = .init(units: 1234, scale: 2)   // 12.34
		let value2: Decimals = .init(units: 999999, scale: 3) // 999.999

		let result1: String = value1.description
		let result2: String = value2.description

		#expect(result1 == "12.34")
		#expect(result2 == "999.999")
	}
}
