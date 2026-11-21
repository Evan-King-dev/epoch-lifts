import Testing
import WorkoutCore

struct SetInputTests {

    @Test(arguments: [
        ("225", 225.0),
        ("22.5", 22.5),
        ("0", 0.0),
        ("  135 ", 135.0),
    ])
    func weightAcceptsNumbersZeroOrMore(text: String, expected: Double) {
        #expect(SetInput.weightLb(from: text) == expected)
    }

    @Test(arguments: ["", "   ", "abc", "-5", "nan", "inf", "22,5"])
    func weightRejectsInvalidText(text: String) {
        #expect(SetInput.weightLb(from: text) == nil)
    }

    @Test(arguments: [
        ("1", 1),
        ("12", 12),
        (" 5 ", 5),
    ])
    func repsAcceptsWholeNumbersOneOrMore(text: String, expected: Int) {
        #expect(SetInput.reps(from: text) == expected)
    }

    @Test(arguments: ["", "0", "-1", "2.5", "x"])
    func repsRejectsInvalidText(text: String) {
        #expect(SetInput.reps(from: text) == nil)
    }

    @Test(arguments: [
        (225.0, "225"),
        (22.5, "22.5"),
        (0.0, "0"),
    ])
    func weightTextDropsTrailingZero(weight: Double, expected: String) {
        #expect(SetInput.text(forWeightLb: weight) == expected)
    }

    @Test(arguments: [225.0, 22.5, 0.0, 137.5])
    func weightTextParsesBackToSameWeight(weight: Double) {
        #expect(SetInput.weightLb(from: SetInput.text(forWeightLb: weight)) == weight)
    }
}
