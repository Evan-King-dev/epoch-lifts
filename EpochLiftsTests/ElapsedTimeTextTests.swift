import Foundation
import Testing
@testable import EpochLifts

@MainActor
struct ElapsedTimeTextTests {

    @Test(arguments: [
        (0.0, "0:00:00"),
        (307.0, "0:05:07"),
        (307.9, "0:05:07"),
        (3725.0, "1:02:05"),
    ])
    func formatsElapsedTimeRoundingDown(seconds: TimeInterval, expected: String) {
        #expect(elapsedTimeText(seconds) == expected)
    }
}
