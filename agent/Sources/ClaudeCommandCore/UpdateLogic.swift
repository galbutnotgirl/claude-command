// UpdateLogic.swift — pure release-channel + version-comparison logic used by
// Updater.swift. No networking, no UserDefaults — just data in, data out, so
// it's unit-testable without hitting the GitHub API.

import Foundation

// Mapped onto GitHub release tags: stable = plain "vX.Y.Z", beta = "vX.Y.Z-beta.N",
// alpha = "vX.Y.Z-alpha.N". A channel sees its own builds AND everything more
// stable (alpha -> alpha+beta+stable, beta -> beta+stable, stable -> stable only), so a
// tester always lands on the newest build they've opted into.
public enum UpdateChannel: String, CaseIterable, Sendable {
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

// SemVer precedence used by updater. Tolerant of missing core components and a
// leading "v" (1.2 equals 1.2.0). Stable beats prerelease at same core version;
// prerelease identifiers use SemVer numeric/lexical ordering.
public func versionGreater(_ a: String, _ b: String) -> Bool {
    struct Version {
        let core: [Int]
        let prerelease: [String]?
    }
    func parse(_ value: String) -> Version {
        let trimmed = value.lowercased().hasPrefix("v") ? String(value.dropFirst()) : value
        let sections = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = sections[0].split(separator: ".", omittingEmptySubsequences: false)
            .map { Int($0.filter(\.isNumber)) ?? 0 }
        let prerelease = sections.count > 1
            ? sections[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            : nil
        return Version(core: core, prerelease: prerelease)
    }
    let va = parse(a), vb = parse(b)
    for i in 0..<max(va.core.count, vb.core.count) {
        let x = i < va.core.count ? va.core[i] : 0
        let y = i < vb.core.count ? vb.core[i] : 0
        if x != y { return x > y }
    }

    switch (va.prerelease, vb.prerelease) {
    case (nil, nil): return false
    case (nil, .some): return true
    case (.some, nil): return false
    case let (.some(pa), .some(pb)):
        for i in 0..<max(pa.count, pb.count) {
            if i >= pa.count { return false }
            if i >= pb.count { return true }
            let left = pa[i], right = pb[i]
            if left == right { continue }
            switch (Int(left), Int(right)) {
            case let (.some(x), .some(y)): return x > y
            case (.some, nil): return false
            case (nil, .some): return true
            case (nil, nil): return left > right
            }
        }
        return false
    }
}

public struct ReleaseAssetInfo: Equatable, Sendable {
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
        return name.hasPrefix("command-")
            && name.hasSuffix(".zip")
            && url.hasSuffix(".zip")
            && !name.hasSuffix(".zip.sha256")
            && !url.hasSuffix(".zip.sha256")
    }
}

public func newestAcceptedReleaseTag(from tags: [String], channel: UpdateChannel) -> String? {
    tags.filter { channel.accepts.contains(UpdateChannel.of(tag: $0)) }
        .max { left, right in versionGreater(right, left) }
}
