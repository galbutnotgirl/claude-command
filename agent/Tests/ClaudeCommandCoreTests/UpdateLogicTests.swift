import XCTest
@testable import ClaudeCommandCore

final class UpdateLogicTests: XCTestCase {
    // ---- versionGreater -------------------------------------------------------

    func testStrictlyNewerPatch() {
        XCTAssertTrue(versionGreater("1.2.1", "1.2.0"))
        XCTAssertFalse(versionGreater("1.2.0", "1.2.1"))
    }

    func testEqualVersionsNotGreater() {
        XCTAssertFalse(versionGreater("1.2.0", "1.2.0"))
    }

    func testLeadingVIsIgnored() {
        XCTAssertFalse(versionGreater("v1.2.0", "1.2.0"))
        XCTAssertTrue(versionGreater("v1.2.1", "1.2.0"))
    }

    func testMissingComponentsTreatedAsZero() {
        // Doc comment: "1.2 vs 1.2.0 → equal".
        XCTAssertFalse(versionGreater("1.2", "1.2.0"))
        XCTAssertFalse(versionGreater("1.2.0", "1.2"))
    }

    func testAlphaSuffixNumberStillComparesWithinSameBase() {
        XCTAssertTrue(versionGreater("1.2.0-alpha.2", "1.2.0-alpha.1"))
        XCTAssertFalse(versionGreater("1.2.0-alpha.1", "1.2.0-alpha.2"))
        XCTAssertTrue(versionGreater("1.2.0-alpha.10", "1.2.0-alpha.2"))
    }

    func testStableAndBetaBeatLessStableBuildsAtSameCoreVersion() {
        XCTAssertTrue(versionGreater("1.2.0", "1.2.0-beta.9"))
        XCTAssertTrue(versionGreater("1.2.0-beta.1", "1.2.0-alpha.99"))
        XCTAssertFalse(versionGreater("1.2.0-alpha.8", "1.2.0"))
        XCTAssertFalse(versionGreater("1.2.0-alpha.8", "1.2.0-beta.1"))
    }

    // Regression guard for the isNewer fix in Updater.swift's check(): a
    // locally-built version ahead of the latest tag must never look "newer"
    // in the wrong direction just because the strings differ.
    func testNotNewerWhenCurrentIsAheadOfLatestTag() {
        XCTAssertFalse(versionGreater("1.2.0-alpha.1", "1.3.0-dev"))
    }

    // ---- UpdateChannel ----------------------------------------------------------

    func testChannelOfTagDetection() {
        XCTAssertEqual(UpdateChannel.of(tag: "v1.2.0-alpha.2"), .alpha)
        XCTAssertEqual(UpdateChannel.of(tag: "v1.2.0-beta.1"), .beta)
        XCTAssertEqual(UpdateChannel.of(tag: "v1.2.0"), .stable)
        XCTAssertEqual(UpdateChannel.of(tag: "V1.2.0-ALPHA.2"), .alpha) // case-insensitive
    }

    func testChannelLabelsMatchUserFacingNames() {
        XCTAssertEqual(UpdateChannel.alpha.label, "Alpha")
        XCTAssertEqual(UpdateChannel.beta.label, "Beta")
        XCTAssertEqual(UpdateChannel.stable.label, "Stable")
    }

    func testAlphaChannelAcceptsEverything() {
        XCTAssertEqual(UpdateChannel.alpha.accepts, Set([.alpha, .beta, .stable]))
    }

    func testStableChannelAcceptsOnlyStable() {
        XCTAssertEqual(UpdateChannel.stable.accepts, Set([.stable]))
    }

    func testBetaChannelDoesNotAcceptAlpha() {
        XCTAssertFalse(UpdateChannel.beta.accepts.contains(.alpha))
        XCTAssertTrue(UpdateChannel.beta.accepts.contains(.beta))
        XCTAssertTrue(UpdateChannel.beta.accepts.contains(.stable))
    }

    func testNewestAcceptedReleaseUsesSemVerInsteadOfPublishOrder() {
        let tags = ["v1.2.0-alpha.2", "v1.2.0", "v1.2.0-alpha.10", "v1.1.9"]
        XCTAssertEqual(newestAcceptedReleaseTag(from: tags, channel: .alpha), "v1.2.0")
        XCTAssertEqual(newestAcceptedReleaseTag(from: tags, channel: .stable), "v1.2.0")
    }

    func testNewestAcceptedReleaseHonorsChannel() {
        let tags = ["v2.0.0-alpha.1", "v1.9.0-beta.2", "v1.8.0"]
        XCTAssertEqual(newestAcceptedReleaseTag(from: tags, channel: .beta), "v1.9.0-beta.2")
        XCTAssertEqual(newestAcceptedReleaseTag(from: tags, channel: .stable), "v1.8.0")
    }

    // ---- Release assets --------------------------------------------------------

    func testDownloadableZipAssetSkipsChecksumAndChoosesAppZip() {
        let checksum = ReleaseAssetInfo(
            name: "Command-1.2.0-alpha.6.zip.sha256",
            browserDownloadURL: "https://example.com/Command-1.2.0-alpha.6.zip.sha256")
        let appZip = ReleaseAssetInfo(
            name: "Command-1.2.0-alpha.6.zip",
            browserDownloadURL: "https://example.com/Command-1.2.0-alpha.6.zip")

        XCTAssertEqual(downloadableZipAsset(from: [checksum, appZip]), appZip)
    }

    func testDownloadableZipAssetRequiresZipNameAndURL() {
        let renamedZip = ReleaseAssetInfo(
            name: "Command-1.2.0-alpha.6.zip",
            browserDownloadURL: "https://example.com/download")
        let misleadingURL = ReleaseAssetInfo(
            name: "checksum.txt",
            browserDownloadURL: "https://example.com/Command-1.2.0-alpha.6.zip")

        XCTAssertNil(downloadableZipAsset(from: [renamedZip, misleadingURL]))
    }

    func testDownloadableZipAssetRejectsUnrelatedZip() {
        let unrelated = ReleaseAssetInfo(
            name: "debug-symbols.zip",
            browserDownloadURL: "https://example.com/debug-symbols.zip")
        XCTAssertNil(downloadableZipAsset(from: [unrelated]))
    }
}
