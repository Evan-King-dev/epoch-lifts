import Foundation
import Testing
@testable import EpochLifts

@MainActor
struct RestTimeTextTests {

    @Test(arguments: [
        (0.0, "0:00"),
        (0.2, "0:01"),
        (119.1, "2:00"),
        (120.0, "2:00"),
        (600.0, "10:00"),
    ])
    func formatsRestTimeRoundingUp(seconds: TimeInterval, expected: String) {
        #expect(restTimeText(seconds) == expected)
    }
}
