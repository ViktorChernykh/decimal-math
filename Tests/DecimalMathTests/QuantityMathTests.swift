@testable import DecimalMath
import Testing

struct QuantityMathTests {

	// MARK: - roundToLot (quantity in Decimals)

	@Test("roundToLot: floor/ceil/nearest on positive quantities")
	func roundToLot_basicPositive() {
		let q: Decimals = .init(units: 123, scale: 0) // 123 pcs, lot=10

		// floor: 120
		let f: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .floor)
		#expect(f.units == 120 && f.scale == 0)

		// ceil: 130
		let c: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .ceil)
		#expect(c.units == 130 && c.scale == 0)

		// nearest: 120 (since 3 < 5)
		let n: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .nearest)
		#expect(n.units == 120 && n.scale == 0)
	}

	@Test("roundToLot: floor/ceil/nearest on negative quantities (short)")
	func roundToLot_basicNegative() {
		let q: Decimals = .init(units: -123, scale: 0) // -123 pcs, lot=10

		// floor: toward -∞ → -130
		let f: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .floor)
		#expect(f.units == -130)

		// ceil: toward +∞ → -120
		let c: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .ceil)
		#expect(c.units == -120)

		// nearest: 3 < 5 → to -120 (toward zero)
		let n: Decimals = QuantityMath.roundToLot(q, lotSize: 10, mode: .nearest)
		#expect(n.units == -120)
	}

	@Test("roundToLot: nearest half-to-even (even lot size)")
	func roundToLot_halfToEven() {
		// lotSize = 10 (even), remainder = exactly 5 should trigger tie.
		// Build q = (div * lot) + 5, test even/odd div parity.

		// div is even (12), q = 12*10 + 5 = 125 → tie → stay on even → 120
		let qEven: Decimals = .init(units: 125, scale: 0)
		let rEven: Decimals = QuantityMath.roundToLot(qEven, lotSize: 10, mode: .nearest)
		#expect(rEven.units == 120)

		// div is odd (11), q = 11*10 + 5 = 115 → tie → move to even → 120
		let qOdd: Decimals = .init(units: 115, scale: 0)
		let rOdd: Decimals = QuantityMath.roundToLot(qOdd, lotSize: 10, mode: .nearest)
		#expect(rOdd.units == 120)
	}

	// MARK: - clamp

	@Test("clamp: returns bounds when out of range, identity otherwise")
	func clamp_basic() {
		let minQ: Decimals = .init(units: 100, scale: 0)
		let maxQ: Decimals = .init(units: 200, scale: 0)

		#expect(QuantityMath.clamp(.init(units: 50,  scale: 0), min: minQ, max: maxQ).units == 100)
		#expect(QuantityMath.clamp(.init(units: 250, scale: 0), min: minQ, max: maxQ).units == 200)
		#expect(QuantityMath.clamp(.init(units: 150, scale: 0), min: minQ, max: maxQ).units == 150)
	}

	// MARK: - roundToTick (price in Decimals)

	@Test("roundToTick: floor/ceil/nearest on positive prices")
	func roundToTick_basic() {
		let price: Decimals = .init(units: 12_345, scale: 2) // 123.45, tick = 5 minor units = 0.05

		// floor: 123.45 already on grid → stays
		let f: Decimals = QuantityMath.roundToTick(price, tick: 5, mode: .floor)
		#expect(f.units == 12_345)

		// ceil: add 1 tick if off-grid; here on-grid → stays
		let c: Decimals = QuantityMath.roundToTick(price, tick: 5, mode: .ceil)
		#expect(c.units == 12_345)

		// nearest: on-grid → stays
		let n: Decimals = QuantityMath.roundToTick(price, tick: 5, mode: .nearest)
		#expect(n.units == 12_345)
	}

	@Test("roundToTick: nearest half-to-even on tick ties")
	func roundToTick_tie() {
		// tick = 10 (0.10). Build price midway: div=even vs odd.
		// Let units= scale=2; tick=10 → half = 5 minor units.

		// div even: (12 * 10) + 5 = 125 → tie → stay at 120
		let pEven: Decimals = .init(units: 125, scale: 2) // 1.25
		let rEven: Decimals = QuantityMath.roundToTick(pEven, tick: 10, mode: .nearest)
		#expect(rEven.units == 120)

		// div odd: (11 * 10) + 5 = 115 → tie → move to 120
		let pOdd: Decimals = .init(units: 115, scale: 2) // 1.15
		let rOdd: Decimals = QuantityMath.roundToTick(pOdd, tick: 10, mode: .nearest)
		#expect(rOdd.units == 120)
	}

	// MARK: - notional (price × quantity)

	@Test("notional: price * quantity with quantity scale")
	func notional_basic() {
		// price = 123.45 (scale 2)
		let price: Decimals = .init(units: 12_345, scale: 2)
		// quantity = 12.345 (scale 3)
		let qty: Decimals = .init(units: 12_345, scale: 3)

		// notional = price * (qty.units / 10^3)
		// = 123.45 * 12.345 = 1524.98025 → scale 2 (banker's) → 1524.98
		let notional: Decimals = QuantityMath.notional(price: price, quantity: qty)
		#expect(notional.scale == 2)
		#expect(notional.units == 152_399) // 1523.99
	}

	// MARK: - vwap

	@Test("vwap: weighted average in price scale, non-empty fills")
	func vwap_basic() {
		// Fill1: q=10.000 (scale=3), p=100.00
		let q1: Decimals = .init(units: 10_000, scale: 3)
		let p1: Decimals = .init(units: 10_000, scale: 2)

		// Fill2: q=20.000, p=110.00
		let q2: Decimals = .init(units: 20_000, scale: 3)
		let p2: Decimals = .init(units: 11_000, scale: 2)

		// Notional = 10*100 + 20*110 = 1000 + 2200 = 3200
		// Qty total = 30 → VWAP = 3200/30 = 106.666... → 106.67 banker’s
		let v: Decimals = QuantityMath.vwap(fills: [(q1, p1), (q2, p2)])
		#expect(v.scale == 2)
		#expect(v.units == 10_667)
	}

	// MARK: - applyBps / applyRatio

	@Test("applyBps: positive and negative adjustments")
	func applyBps_basic() {
		let price: Decimals = .init(units: 10_000, scale: 2) // 100.00

		// +100 bps = +1%
		let up: Decimals = QuantityMath.applyBps(price, bps: 100) // 101.00
		#expect(up.units == 10_100)

		// -50 bps = -0.5% → 99.50
		let dn: Decimals = QuantityMath.applyBps(price, bps: -50)
		#expect(dn.units == 9_950)
	}

	@Test("applyRatio: arbitrary pctNumerator/pctDenominator")
	func applyRatio_basic() {
		let price: Decimals = .init(units: 20_000, scale: 2) // 200.00

		// +10% → (1 + 10/100) = 1.1 → 220.00
		let up: Decimals = QuantityMath.applyRatio(price, pctNumerator: 10, pctDenominator: 100)
		#expect(up.units == 22_000)

		// -2.5% → (1 - 2.5/100) = 0.975 → 195.00
		let dn: Decimals = QuantityMath.applyRatio(price, pctNumerator: -25, pctDenominator: 1000)
		#expect(dn.units == 19_500)
	}

	// MARK: - maxBuyQuantity

	@Test("maxBuyQuantity: respects budget, quantityScale and lot rounding")
	func maxBuyQuantity_basic() {
		// Budget 1000.00, unitPrice 12.34, quantityScale=0 (integer pieces), lot=10, fee=0
		let budget: Decimals = .init(units: 100_000, scale: 2)	// 1000.00
		let price: Decimals = .init(units: 1_234, scale: 2)		// 12.34

		// Max pieces without fee: floor(1000 / 12.34) = 81 → rounded down to lot(10) = 80
		let q: Decimals = QuantityMath.maxBuyQuantity(
			budget: budget,
			unitPrice: price,
			quantityScale: 0,
			lotSize: 10,
			feeBps: 0
		)
		#expect(q.scale == 0)
		#expect(q.units == 80)
	}

	@Test("maxBuyQuantity: fee in bps reduces resulting quantity")
	func maxBuyQuantity_fee() {
		let budget: Decimals = .init(units: 100_000, scale: 2) // 1000.00
		let price: Decimals = .init(units: 1_000, scale: 2)    // 10.00

		// Without fee: 100 pcs; with 100 bps (1%) eff price = 10.10 → 99.009.. → 99 pcs
		let qNoFee: Decimals = QuantityMath.maxBuyQuantity(
			budget: budget,
			unitPrice: price,
			quantityScale: 0,
			lotSize: 1,
			feeBps: 0
		)
		let qFee: Decimals = QuantityMath.maxBuyQuantity(
			budget: budget,
			unitPrice: price,
			quantityScale: 0,
			lotSize: 1,
			feeBps: 100
		)
		#expect(qNoFee.units == 100)
		#expect(qFee.units == 99)
	}
}
