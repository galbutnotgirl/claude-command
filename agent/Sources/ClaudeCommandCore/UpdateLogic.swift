// UpdateLogic.swift — pure release-channel + version-comparison logic used by
// Updater.swift. No networking, no UserDefaults — just data in, data out, so
// it's unit-testable without hitting the GitHub API.

import Foundation

// Mapped onto GitHub release tags: stable = plain "vX.Y.Z", beta = "vX.Y.Z-beta.N",
// alpha = "vX.Y.Z-alpha.N". A channel sees its own builds AND everything more
// stable (alpha -> alpha+beta+stable, beta -> beta+stable, stable -> stable only), so a
// tester always lands on the newest build they've opted into.
public enum UpdateChannel: String, CaseIterable {
    case alpha
    case beta
    case stable = "prod"

    public var label: String {
        switch self {
        case .alpha: return "Alpha"
        case .beta: return "Beta"
        case .stable: return "Stable"
        }
    }
    // Channels this selection is allowed to receive (self + more stable).
    public var accepts: Set<UpdateChannel> {
        switch self {
        case .alpha: return [.alpha, .beta, .stable]
        case .beta:  return [.beta, .stable]
        case .stable: return [.stable]
        }
    }
    // Which channel a release tag belongs to.
    public static func of(tag: String) -> UpdateChannel {
        let t = tag.lowercased()
        if t.contains("alpha") { return .alpha }
        if t.contains("beta")  { return .beta }
        return .stable
    }
}

// semver-ish compare: true when `a` is strictly newer than `b`. Tolerant of
// missing components and a leading "v" (1.2 vs 1.2.0 → equal). Numeric
// components only — a "-alpha.N"/"-beta.N" suffix's own N still compares
// (1.2.0-alpha.2 > 1.2.0-alpha.1), just not against differently-labeled
// suffixes with real semver precedence (not needed here: the updater always
// compares tags within one release list, not across arbitrary strings).
public func versionGreater(_ a: String, _ b: String) -> Bool {
    func parts(_ s: String) -> [Int] {
        let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
        return trimmed.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
    let pa = parts(a), pb = parts(b)
    for i in 0..<max(pa.count, pb.count) {
        let x = i < pa.count ? pa[i] : 0
        let y = i < pb.count ? pb[i] : 0
        if x != y { return x > y }
    }
    return false
}

public struct ReleaseAssetInfo: Equatable {
    public var name: String
    public var browserDownloadURL: String

    public init(name: String, browserDownloadURL: String) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
    }
}

public func downloadableZipAsset(from assets: [ReleaseAssetInfo]) -> ReleaseAssetInfo? {
    assets.first { asset in
        let name = asset.name.lowercased()
        let url = asset.browserDownloadURL.lowercased()
        return name.hasSuffix(".zip")
            && url.hasSuffix(".zip")
            && !name.hasSuffix(".zip.sha256")
            && !url.hasSuffix(".zip.sha256")
    }
}
