import XCTest
@testable import ClaudeCommandCore

final class ClipboardURLTests: XCTestCase {
    func testNormalizesWebAndSchemeLessURLs() {
        XCTAssertEqual(detectClipboardURL("https://example.com/path")?.normalized,
                       "https://example.com/path")
        XCTAssertEqual(detectClipboardURL("example.com/path?q=1#top")?.normalized,
                       "https://example.com/path?q=1#top")
        XCTAssertEqual(detectClipboardURL("  example.com/path. \n")?.normalized,
                       "https://example.com/path")
    }

    func testAcceptsLocalhostAndIPAddressesWithoutScheme() {
        XCTAssertEqual(detectClipboardURL("localhost:3000/test")?.normalized,
                       "https://localhost:3000/test")
        XCTAssertEqual(detectClipboardURL("192.168.1.20:8080")?.normalized,
                       "https://192.168.1.20:8080")
        XCTAssertEqual(detectClipboardURL("[::1]:3000")?.normalized,
                       "https://[::1]:3000")
    }

    func testRejectsEmbeddedURLsAndOrdinaryText() {
        XCTAssertNil(detectClipboardURL("See example.com for details"))
        XCTAssertNil(detectClipboardURL("first line\nexample.com"))
        XCTAssertNil(detectClipboardURL("person@example.com"))
        XCTAssertNil(detectClipboardURL("hello"))
        XCTAssertNil(detectClipboardURL("ftp://example.com"))
    }

    func testExplicitHTTPAcceptsLocalHosts() {
        XCTAssertEqual(detectClipboardURL("http://localhost:8080")?.normalized,
                       "http://localhost:8080")
        XCTAssertEqual(detectClipboardURL("https://10.0.0.2/a")?.normalized,
                       "https://10.0.0.2/a")
    }
}
