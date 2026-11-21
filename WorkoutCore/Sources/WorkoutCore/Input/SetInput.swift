import Foundation

/// Converts the text typed into a set's weight and reps boxes into numbers, and weights back
/// into text for pre-filling the weight box (ADR-015).
///
/// Example: `SetInput.weightLb(from: "22.5")` returns `22.5`; `SetInput.reps(from: "0")` returns `nil`.
public enum SetInput {
    /// Parses a weight in pounds. Accepts any finite number of 0 or more (0 means bodyweight).
    /// Returns `nil` for empty, non-numeric, negative or non-finite input.
    public static func weightLb(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let weight = Double(trimmed), weight.isFinite, weight >= 0 else {
            return nil
        }
        return weight
    }

    /// Parses a rep count. Accepts whole numbers of 1 or more.
    /// Returns `nil` for empty, non-numeric, fractional, zero or negative input.
    public static func reps(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let reps = Int(trimmed), reps >= 1 else {
            return nil
        }
        return reps
    }

    /// Formats a weight for the weight box, without a trailing ".0" for whole numbers.
    /// Example: `225.0` becomes `"225"`, `22.5` stays `"22.5"`.
    public static func text(forWeightLb weight: Double) -> String {
        if weight == weight.rounded(), abs(weight) < 1_000_000 {
            return String(Int(weight))
        }
        return String(weight)
    }
}
