import XCTest
@testable import ClaudeCommandCore

final class OnboardingLogicTests: XCTestCase {
    func testFreshInstallStartsAtWelcomeEvenWhenSystemPermissionsAlreadyExist() {
        let progress = OnboardingProgress(
            primaryAssistantSelected: false,
            accessibilityGranted: true,
            screenRecordingGranted: true,
            microphoneStepCompleted: false,
            clipboardStepCompleted: false
        )
        XCTAssertEqual(progress.resumeStep, .welcome)
    }

    func testResumeStopsAtFirstIncompletePermissionOrChoice() {
        XCTAssertEqual(progress(false, false, false, false).resumeStep, .accessibility)
        XCTAssertEqual(progress(true, false, false, false).resumeStep, .screenRecording)
        XCTAssertEqual(progress(true, true, false, false).resumeStep, .microphone)
        XCTAssertEqual(progress(true, true, true, false).resumeStep, .clipboard)
        XCTAssertEqual(progress(true, true, true, true).resumeStep, .done)
    }

    func testLaterCompletionFlagsNeverSkipEarlierRequiredStep() {
        let progress = OnboardingProgress(
            primaryAssistantSelected: true,
            accessibilityGranted: false,
            screenRecordingGranted: true,
            microphoneStepCompleted: true,
            clipboardStepCompleted: true
        )
        XCTAssertEqual(progress.resumeStep, .accessibility)
    }

    private func progress(
        _ accessibility: Bool,
        _ screenRecording: Bool,
        _ microphone: Bool,
        _ clipboard: Bool
    ) -> OnboardingProgress {
        OnboardingProgress(
            primaryAssistantSelected: true,
            accessibilityGranted: accessibility,
            screenRecordingGranted: screenRecording,
            microphoneStepCompleted: microphone,
            clipboardStepCompleted: clipboard
        )
    }
}
