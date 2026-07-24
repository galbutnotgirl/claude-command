import Foundation

public struct DetectedClipboardURL: Equatable, Sendable {
    public let original: String
    public let normalized: String

    public init(original: String, normalized: String) {
        self.original = original
        self.normalized = normalized
    }
}

public enum ClipboardPickerModifier: String, CaseIterable, Sendable {
    case command, option, shift, control

    public var label: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .shift: return "Shift"
        case .control: return "Control"
        }
    }

    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .control: return "⌃"
        }
    }
}

public enum ClipboardPickerSettingsKeys {
    public static let newSessionEnabled = "clipboardPickerNewSessionEnabled"
    public static let newSessionModifier = "clipboardPickerNewSessionModifier"
    public static let sendAssistantEnabled = "clipboardPickerSendAssistantEnabled"
    public static let sendAssistantModifier = "clipboardPickerSendAssistantModifier"
    public static let openURLEnabled = "clipboardPickerOpenURLEnabled"
    public static let openURLModifier = "clipboardPickerOpenURLModifier"
}

public func detectClipboardURL(_ value: String) -> DetectedClipboardURL? {
    let original = value
    var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else { return nil }
    if candidate.hasSuffix(".") { candidate.removeLast() }
    guard !candidate.isEmpty,
          candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }

    let lower = candidate.lowercased()
    let hasScheme = lower.hasPrefix("http://") || lower.hasPrefix("https://")
    if candidate.contains("://") && !hasScheme { return nil }
    if !hasScheme && candidate.contains("@") { return nil }

    let normalized = hasScheme ? candidate : "https://\(candidate)"
    guard let components = URLComponents(string: normalized),
          let scheme = components.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = components.host, !host.isEmpty else { return nil }

    if !hasScheme {
        let lowerHost = host.lowercased()
        let isLocalhost = lowerHost == "localhost"
        let isIPv4 = lowerHost.split(separator: ".").count == 4
            && lowerHost.split(separator: ".").allSatisfy {
                Int($0).map { (0...255).contains($0) } == true
            }
        let isIPv6 = lowerHost.contains(":")
        guard isLocalhost || isIPv4 || isIPv6 || lowerHost.contains(".") else { return nil }
    }

    guard URL(string: normalized) != nil else { return nil }
    return DetectedClipboardURL(original: original, normalized: normalized)
}
