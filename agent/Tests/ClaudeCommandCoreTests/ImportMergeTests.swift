import XCTest
@testable import ClaudeCommandCore

final class ImportMergeTests: XCTestCase {
    func testMergeDictionaryArraysIncomingWinsByKeyAndKeepsOrder() {
        let current: [[String: Any]] = [
            ["action": "add", "keycode": 100],
            ["action": "go", "keycode": 0],
        ]
        let incoming: [[String: Any]] = [
            ["action": "go", "keycode": 101],
            ["action": "comment", "keycode": 98],
        ]

        let merged = mergeDictionaryArrays(current: current, incoming: incoming, key: "action")
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0]["action"] as? String, "add")
        XCTAssertEqual(merged[1]["action"] as? String, "go")
        XCTAssertEqual(merged[1]["keycode"] as? Int, 101)
        XCTAssertEqual(merged[2]["action"] as? String, "comment")
    }

    func testMergeDictionaryValuesIncomingWins() {
        let merged = mergeDictionaryValues(
            current: ["add": "{selection}", "go": "old"],
            incoming: ["go": "new", "comment": "comment"]
        )

        XCTAssertEqual(merged["add"] as? String, "{selection}")
        XCTAssertEqual(merged["go"] as? String, "new")
        XCTAssertEqual(merged["comment"] as? String, "comment")
    }

    func testMergeEnrichRulesKeepsSameHostDifferentPathPrefixesDistinct() {
        let current: [[String: Any]] = [
            ["match": "host", "pattern": "docs.google.com", "pathPrefix": "/document/", "text": "Docs"],
            ["match": "host", "pattern": "docs.google.com", "pathPrefix": "/spreadsheets/", "text": "Sheets"],
        ]
        let incoming: [[String: Any]] = [
            ["match": "host", "pattern": "docs.google.com", "pathPrefix": "/presentation/", "text": "Slides"],
            ["match": "host", "pattern": "docs.google.com", "pathPrefix": "/document/", "text": "Docs updated"],
        ]

        let merged = mergeEnrichRuleDictionaries(current: current, incoming: incoming)
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0]["text"] as? String, "Docs updated")
        XCTAssertEqual(merged[1]["text"] as? String, "Sheets")
        XCTAssertEqual(merged[2]["text"] as? String, "Slides")
    }

    func testMergeVocabularyUnionsTermsAndIncomingCorrectionWins() {
        let current: [String: Any] = [
            "vocab": ["Contentstack", "AXP"],
            "replacements": [["wrong": "ax pea", "correct": "AXP"]],
            "fillers": [["phrase": "um", "enabled": true]],
        ]
        let incoming: [String: Any] = [
            "vocab": ["AXP", "Personalize"],
            "replacements": [["wrong": "ax pea", "correct": "AXP strategy"]],
            "fillers": [["phrase": "you know", "enabled": false]],
        ]

        let merged = mergeVocabularyDictionaries(current: current, incoming: incoming)
        XCTAssertEqual(merged["vocab"] as? [String], ["AXP", "Contentstack", "Personalize"])
        let replacements = merged["replacements"] as? [[String: Any]]
        XCTAssertEqual(replacements?.count, 1)
        XCTAssertEqual(replacements?.first?["correct"] as? String, "AXP strategy")
        let fillers = merged["fillers"] as? [[String: Any]]
        XCTAssertEqual(fillers?.count, 2)
    }
}
