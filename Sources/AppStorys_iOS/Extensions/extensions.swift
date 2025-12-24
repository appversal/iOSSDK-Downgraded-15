import Foundation
public extension StringOrInt {
    var cgFloatValue: CGFloat {
        let cleaned = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return CGFloat(Double(cleaned) ?? 0)
    }
}
