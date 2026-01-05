// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DecimalMath",
    platforms: [
		.macOS(.v14),
		.iOS(.v17)
    ],
    products: [
        .library(name: "DecimalMath", targets: ["DecimalMath"]),
    ],
    dependencies: [],
	targets: [
		.target(
			name: "DecimalMath",
			dependencies: [],
			swiftSettings: swiftSettings
		),
		.testTarget(
			name: "DecimalMathTests",
			dependencies: ["DecimalMath"]
		)
	]
)

/// Swift compiler settings for Release configuration.
var swiftSettings: [SwiftSetting] { [
	// "ExistentialAny" is an option that makes the use of the `any` keyword for existential types `required`
	.enableUpcomingFeature("ExistentialAny")
] }
