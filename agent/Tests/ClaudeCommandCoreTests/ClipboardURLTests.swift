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

    func testFilterNavigationIncludesURLsInStableOrder() {
        XCTAssertEqual(ClipboardHistoryFilter.text.adjacent(step: 1), .urls)
        XCTAssertEqual(ClipboardHistoryFilter.urls.adjacent(step: -1), .text)
        XCTAssertEqual(ClipboardHistoryFilter.sent.adjacent(step: 1), .images)
    }

    func testPasteNormalizesOnlyWholeValueURLs() {
        XCTAssertEqual(clipboardPasteText(" example.com/path. \n"), "https://example.com/path")
        XCTAssertEqual(clipboardPasteText("See example.com for details"), "See example.com for details")
    }

    func testPickerRoutesConfiguredURLAndAssistantActions() {
        let bindings = [
            ClipboardPickerActionBinding(action: .openURL, modifier: .shift, enabled: true),
            ClipboardPickerActionBinding(action: .newSession, modifier: .command, enabled: true),
            ClipboardPickerActionBinding(action: .sendToAssistant, modifier: .option, enabled: true),
        ]
        XCTAssertEqual(clipboardPickerAction(isURL: true, pressedModifiers: [.shift], bindings: bindings),
                       .openURL)
        XCTAssertEqual(clipboardPickerAction(isURL: false, pressedModifiers: [.shift], bindings: bindings),
                       .paste)
        XCTAssertEqual(clipboardPickerAction(isURL: false, pressedModifiers: [.command], bindings: bindings),
                       .newSession)
        XCTAssertEqual(clipboardPickerAction(isURL: true, pressedModifiers: [.option], bindings: bindings),
                       .sendToAssistant)
    }

    func testDisabledPickerBindingFallsBackToPaste() {
        let bindings = [
            ClipboardPickerActionBinding(action: .openURL, modifier: .shift, enabled: false),
        ]
        XCTAssertEqual(clipboardPickerAction(isURL: true, pressedModifiers: [.shift], bindings: bindings),
                       .paste)
    }
}
