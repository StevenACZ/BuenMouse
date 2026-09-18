import AppKit
import Sparkle
import XCTest

@testable import BuenMouse

@MainActor
private final class UpdaterSessionSpy {
    var isInProgress = false
    var checkCount = 0
    var backgroundCheckCount = 0
    var onCheckForUpdates: (() -> Void)?
    var onCheckForUpdatesInBackground: (() -> Void)?

    var session: UpdateManager.UpdaterSession {
        UpdateManager.UpdaterSession(
            isInProgress: { self.isInProgress },
            checkForUpdates: {
                self.checkCount += 1
                self.onCheckForUpdates?()
            },
            checkForUpdatesInBackground: {
                self.backgroundCheckCount += 1
                self.onCheckForUpdatesInBackground?()
            }
        )
    }
}

@MainActor
final class UpdateManagerTests: XCTestCase {

    private var manager: UpdateManager!
    private var savedAutoCheckDefault: Any?
    private var discoveryNow: TimeInterval = 0

    override func setUp() async throws {
        try await super.setUp()
        savedAutoCheckDefault = UserDefaults.standard.object(
            forKey: UpdateManager.autoCheckDefaultsKey)
        manager = UpdateManager()
        manager.resumeCheckPollNanoseconds = 1_000
    }

    override func tearDown() async throws {
        manager.stopBackgroundDiscovery()
        manager = nil
        if let savedAutoCheckDefault {
            UserDefaults.standard.set(
                savedAutoCheckDefault, forKey: UpdateManager.autoCheckDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UpdateManager.autoCheckDefaultsKey)
        }
        savedAutoCheckDefault = nil
        try await super.tearDown()
    }

    // MARK: - Scheduled check surfaces a pending card

    func testScheduledFoundUpdateIsDismissedAndSurfaced() {
        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            stage: .notDownloaded,
            releasePage: URL(string: "https://example.com/release"),
            informationOnly: false
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.releasePageURL?.absoluteString, "https://example.com/release")
    }

    func testInformationOnlyUpdateOpensTheReleasePageInsteadOfDownloading() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: true)

        manager.installPendingUpdate()

        XCTAssertEqual(spy.checkCount, 0)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    // MARK: - Download progress

    func testDownloadProgressIsFractionOfExpectedLength() {
        manager.handleDownloadInitiated()
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))

        manager.handleDownloadExpectedLength(1_000)
        manager.handleDownloadReceived(bytes: 250)
        XCTAssertEqual(manager.phase, .downloading(fraction: 0.25))

        manager.handleDownloadReceived(bytes: 750)
        XCTAssertEqual(manager.phase, .downloading(fraction: 1.0))
    }

    func testUnknownContentLengthStaysIndeterminate() {
        manager.handleDownloadInitiated()
        manager.handleDownloadReceived(bytes: 4_096)

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
    }

    func testDownloadFractionIsCappedAtOne() {
        manager.handleDownloadInitiated()
        manager.handleDownloadExpectedLength(100)
        manager.handleDownloadReceived(bytes: 250)

        XCTAssertEqual(manager.phase, .downloading(fraction: 1.0))
    }

    func testExtractionNeverMovesTheProgressBackwards() {
        manager.handleDownloadInitiated()
        manager.handleDownloadExpectedLength(1_000)
        manager.handleDownloadReceived(bytes: 750)

        manager.handleExtractionStarted()

        XCTAssertEqual(manager.phase, .installing)
    }

    // MARK: - Ready to install

    func testReadyToInstallHoldsTheReplyUntilTheUserClicks() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertTrue(manager.canPostpone)
    }

    func testInstallNowRepliesInstall() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.phase, .installing)
    }

    func testInstallLaterRepliesDismissAndClearsCanPostpone() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        manager.installLater()

        XCTAssertEqual(choices, [.dismiss])
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testPostponeIsOfferedOnlyWhileTheReplyIsHeld() {
        XCTAssertFalse(manager.canPostpone)

        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleReadyToInstall { _ in }
        XCTAssertTrue(manager.canPostpone)

        manager.installLater()
        XCTAssertFalse(manager.canPostpone)

        manager.handleReadyToInstall { _ in }
        manager.installNow()
        XCTAssertFalse(manager.canPostpone)

        manager.handleReadyToInstall { _ in }
        XCTAssertTrue(manager.canPostpone)

        manager.handleDismissInstallation()
        XCTAssertFalse(manager.canPostpone)
    }

    func testInstallLaterTwiceRepliesDismissExactlyOnce() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        manager.installLater()
        manager.installLater()

        XCTAssertEqual(choices, [.dismiss])
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testInstallNowTwiceRepliesExactlyOnce() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        manager.installNow()
        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.resumeRequestCount, 0)
    }

    // MARK: - Install now after a postponed update

    func testInstallLaterThenScheduledCheckKeepsTheReadyCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleReadyToInstall { _ in }
        manager.installLater()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testInstallNowAfterLaterInstallsThroughThePreparedStage() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleReadyToInstall { _ in }
        manager.installLater()

        manager.installNow()

        XCTAssertEqual(manager.phase, .installing)
        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertEqual(manager.resumeRequestCount, 1)

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .install)
        XCTAssertEqual(manager.phase, .installing)

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }
        XCTAssertEqual(choices, [.install])
        XCTAssertFalse(manager.canPostpone)
    }

    func testUpdateClickOnAPreparedStageStopsAtTheReadyCard() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testUpdateClickOnAnInstallingStageStopsAtTheReadyCard() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testInstallNowWithoutAnUpdaterLeavesTheCardUntouched() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        manager.installNow()

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertEqual(manager.resumeRequestCount, 0)
    }

    // MARK: - Resume while the old session tears down

    func testUpdateDuringTeardownArmsAResumeThatDoesNotAutoInstall() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(manager.resumeRequestCount, 1)
        XCTAssertTrue(manager.resumeCheckPending)
        XCTAssertEqual(spy.checkCount, 0)

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .install)
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertTrue(manager.canPostpone)
    }

    func testUpdateDuringTeardownOnAPreparedStageStopsAtTheReadyCard() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        manager.installPendingUpdate()
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.resumeCheckPending)
    }

    func testResumePollingStartsTheCheckOnceTheSessionIsFree() async {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        let checkStarted = expectation(description: "resume check reached the seam")
        spy.onCheckForUpdates = { checkStarted.fulfill() }
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.beginRequestedResume()

        XCTAssertEqual(spy.checkCount, 0)
        spy.isInProgress = false
        await fulfillment(of: [checkStarted], timeout: 5)

        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertFalse(manager.resumeCheckPending)
    }

    func testExhaustedResumeAfterAnUpdateClickFails() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()

        manager.handleResumeCheckExhausted()

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    // MARK: - Retry never skips consent

    func testRetryAfterAFailedDownloadStopsAtReadyToInstall() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleError("download failed")
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))

        manager.installNow()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(spy.checkCount, 1)

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .install)
        manager.handleDownloadInitiated()

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertTrue(manager.canPostpone)
    }

    func testRetryOnADownloadedStageStopsAtTheReadyCard() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleError("download failed")

        manager.installNow()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testRetryOnAnInstallingStageStopsAtTheReadyCard() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleError("install failed")

        manager.installNow()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testRetryThenInstallNowStillInstalls() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleError("download failed")
        manager.installNow()
        var replies: [SPUUserUpdateChoice] = []
        var choices: [SPUUserUpdateChoice] = [
            manager.handleUpdateFound(
                version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)
        ]

        XCTAssertEqual(choices, [.dismiss])
        XCTAssertTrue(replies.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.installNow()

        choices.append(
            manager.handleUpdateFound(
                version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)
        )

        XCTAssertEqual(choices, [.dismiss, .install])
        XCTAssertEqual(manager.phase, .installing)

        manager.handleReadyToInstall { replies.append($0) }
        XCTAssertEqual(replies, [.install])
    }

    func testDismissOfTheOldSessionKeepsTheArmedResume() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.beginRequestedResume()

        manager.handleDismissInstallation()

        XCTAssertEqual(manager.phase, .installing)
        XCTAssertTrue(manager.resumeCheckPending)
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .install)
    }

    func testReachingTheNewSessionEndsTheResumeLoop() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.beginRequestedResume()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .install)
        XCTAssertFalse(manager.resumeCheckPending)

        manager.handleResumeCheckExhausted()

        XCTAssertEqual(manager.phase, .installing)
    }

    func testReadyDuringAnArmedResumeEndsThePollAndHoldsTheCard() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.beginRequestedResume(autoInstall: false)

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertFalse(manager.resumeCheckPending)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.handleResumeCheckExhausted()
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.resumeRequestCount, 1)
    }

    func testExhaustedResumeFailsAndDropsTheInstallConsent() {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = true
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.beginRequestedResume()

        manager.handleResumeCheckExhausted()

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    // MARK: - Errors

    func testUserRequestedInstallFailureSurfacesTheRetry() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()

        manager.handleError("download failed")

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    func testScheduledCheckErrorStaysSilent() {
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .dismiss)

        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testScheduledCheckErrorWithNothingPendingStaysIdle() {
        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .idle)
    }

    func testErrorWhileReadyToInstallKeepsTheReadyCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    // MARK: - Session teardown

    func testScheduledCheckOnAPreparedUpdateOffersTheReadyCard() {
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testDismissDuringDownloadRollsBackToAvailable() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleDownloadInitiated()

        manager.handleDismissInstallation()

        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testDismissWhileInstallingKeepsTheReadyCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleExtractionStarted()

        manager.handleDismissInstallation()

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testDismissClearsInstallConsentSoTheNextCheckOnlySurfaces() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()

        manager.handleDismissInstallation()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testNotFoundClearsPendingState() {
        let spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.checkForUpdatesManually()

        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertNil(manager.releasePageURL)
    }

    // MARK: - Silent discovery

    @discardableResult
    private func armDiscovery(sessionInProgress: Bool = false) -> UpdaterSessionSpy {
        let spy = UpdaterSessionSpy()
        spy.isInProgress = sessionInProgress
        discoveryNow = 0
        manager.setAutoCheckEnabled(true)
        manager.stopBackgroundDiscovery()
        manager.updaterSession = spy.session
        manager.monotonicClock = { [unowned self] in self.discoveryNow }
        return spy
    }

    func testPanelOpenAsksForASilentCheck() {
        let spy = armDiscovery()

        manager.popoverDidOpen()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
        XCTAssertEqual(spy.checkCount, 0)
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testTheMenuBarPanelStillCallsTheDiscoveryHook() throws {
        let controller = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Core/MenuBar/MenuBarStatusController.swift")

        let source = try String(contentsOf: controller, encoding: .utf8)
        let buttonLit = try XCTUnwrap(source.range(of: "button.state = .on"))
        let popoverShown = try XCTUnwrap(
            source.range(
                of: "popover.show(relativeTo:", range: buttonLit.upperBound..<source.endIndex))

        XCTAssertNotNil(
            source.range(
                of: "UpdateManager.shared.popoverDidOpen()",
                range: buttonLit.upperBound..<popoverShown.lowerBound))
    }

    func testTheAboutWindowAlsoCallsTheDiscoveryHook() throws {
        let controller = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Core/MenuBar/MenuBarStatusController.swift")

        let source = try String(contentsOf: controller, encoding: .utf8)
        let openAbout = try XCTUnwrap(source.range(of: "func openAboutWindow() {"))
        let aboutPresented = try XCTUnwrap(
            source.range(of: "rootView: AboutView()", range: openAbout.upperBound..<source.endIndex))

        XCTAssertNotNil(
            source.range(
                of: "UpdateManager.shared.popoverDidOpen()",
                range: openAbout.upperBound..<aboutPresented.lowerBound))
    }

    func testTheDiscoveryTimerRunsOnTheRunLoopAndAsksForACheck() async {
        let spy = armDiscovery()
        let checked = expectation(description: "the discovery timer asked for a silent check")
        checked.assertForOverFulfill = false
        spy.onCheckForUpdatesInBackground = { checked.fulfill() }
        manager.backgroundCheckInterval = 0.05

        manager.startBackgroundDiscovery()

        XCTAssertTrue(manager.backgroundDiscoveryArmed)
        await fulfillment(of: [checked], timeout: 5)
        manager.stopBackgroundDiscovery()
        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testWakeFromSleepAsksForASilentCheck() async {
        let spy = armDiscovery()
        let checked = expectation(description: "wake asked for a silent check")
        spy.onCheckForUpdatesInBackground = { checked.fulfill() }
        manager.startBackgroundDiscovery()

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification, object: nil)

        await fulfillment(of: [checked], timeout: 5)
        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testAllTriggersShareTheFiveMinuteThrottle() {
        let spy = armDiscovery()

        manager.popoverDidOpen()
        discoveryNow = UpdateManager.backgroundCheckThrottle - 1
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)

        discoveryNow = UpdateManager.backgroundCheckThrottle
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 2)
    }

    func testSilentCheckIsSkippedWhileASessionIsInProgress() {
        let spy = armDiscovery(sessionInProgress: true)

        manager.popoverDidOpen()

        XCTAssertEqual(spy.backgroundCheckCount, 0)
    }

    func testSilentCheckIsSkippedWhileADownloadRuns() {
        let spy = armDiscovery()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()
        manager.handleDownloadInitiated()

        manager.popoverDidOpen()

        XCTAssertEqual(spy.backgroundCheckCount, 0)
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
    }

    func testTurningAutoChecksOffDisarmsDiscoveryAndFiresNoTrigger() {
        let spy = armDiscovery()
        manager.startBackgroundDiscovery()
        XCTAssertTrue(manager.backgroundDiscoveryArmed)

        manager.setAutoCheckEnabled(false)
        manager.popoverDidOpen()

        XCTAssertFalse(manager.backgroundDiscoveryArmed)
        XCTAssertEqual(spy.backgroundCheckCount, 0)

        manager.setAutoCheckEnabled(true)

        XCTAssertTrue(manager.backgroundDiscoveryArmed)
    }

    func testSilentCheckThatFindsNothingChangesNoVisibleState() {
        armDiscovery()
        manager.popoverDidOpen()

        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
        XCTAssertNil(manager.pendingVersion)
    }

    func testSilentCheckThatFailsChangesNoVisibleState() {
        armDiscovery()
        manager.popoverDidOpen()

        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testSilentCheckThatFindsAnUpdateShowsTheAvailableCard() {
        armDiscovery()
        manager.popoverDidOpen()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    // MARK: - Quiet checks from a resting card

    private func armLaterState() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleReadyToInstall { _ in }
        manager.installLater()
    }

    private func armFailedCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()
        manager.handleError("download died")
    }

    func testIdleAllowsAQuietCheck() {
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testAnAvailableCardAllowsAQuietCheck() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testAFailedCardAllowsAQuietCheck() {
        armDiscovery()
        armFailedCard()

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testDownloadingAndInstallingBlockAQuietCheck() {
        manager.handleDownloadInitiated()
        XCTAssertFalse(manager.phaseAllowsQuietCheck)

        manager.handleExtractionStarted()
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAHeldReadyReplyBlocksAQuietCheck() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleReadyToInstall { _ in }

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testThePostLaterReadyCardBlocksAQuietCheck() {
        armLaterState()

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAUserCheckInFlightBlocksAQuietCheck() {
        armDiscovery(sessionInProgress: true)

        manager.checkForUpdatesManually()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testARequestedRetryBlocksAQuietCheck() {
        armDiscovery(sessionInProgress: true)
        armFailedCard()

        manager.installNow()

        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testARequestedInstallNowBlocksAQuietCheck() {
        armDiscovery(sessionInProgress: true)
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        manager.installNow()

        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAQuietCheckWithoutALiveUpdaterIsSkippedAndKeepsTheThrottleUnused() {
        let spy = armDiscovery()
        manager.updaterSession = nil

        manager.requestBackgroundCheck()

        manager.updaterSession = spy.session
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testAQuietCheckRunsFromAFailedCard() {
        let spy = armDiscovery()
        armFailedCard()

        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    func testAnUnattendedSameVersionKeepsTheFailedCard() {
        armDiscovery()
        armFailedCard()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        XCTAssertEqual(manager.pendingVersion, "9.9.9")
    }

    func testAnUnattendedSameVersionLeavesTheAvailableCardUntouched() {
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            stage: .notDownloaded,
            releasePage: URL(string: "https://example.com/release"),
            informationOnly: false
        )

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.releasePageURL?.absoluteString, "https://example.com/release")
    }

    func testAnUnattendedRestagedUpdateKeepsTheReadyCardAfterLater() {
        armLaterState()

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.canPostpone)
    }

    func testAnUnattendedOlderVersionLeavesTheCardUntouched() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        let choice = manager.handleUpdateFound(
            version: "9.9.8", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.pendingVersion, "9.9.9")
    }

    func testAnUnattendedNewerVersionRefreshesTheAvailableCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        let choice = manager.handleUpdateFound(
            version: "9.9.10", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.10"))
    }

    func testAnUnattendedNewerVersionReplacesTheFailedCard() {
        armDiscovery()
        armFailedCard()

        let choice = manager.handleUpdateFound(
            version: "9.9.10", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.10"))
    }

    func testAnUnattendedNotFoundKeepsTheAvailableCard() {
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.pendingVersion, "9.9.9")
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testAnUnattendedErrorKeepsTheFailedCard() {
        armDiscovery()
        armFailedCard()

        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    func testNotFoundAndErrorAtIdleStillClearEverything() {
        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertNil(manager.pendingVersion)

        manager.handleError("feed unreachable")

        XCTAssertEqual(manager.phase, .idle)
    }

    func testAManualCheckAfterASilentQuietSessionStillReports() {
        let spy = armDiscovery()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.requestBackgroundCheck()
        XCTAssertEqual(spy.backgroundCheckCount, 1)

        manager.checkForUpdatesManually()
        manager.handleNotFound()

        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertEqual(manager.manualCheckStatus, .upToDate)
        XCTAssertEqual(manager.phase, .idle)
    }

    func testAnUpdateClickAfterASilentQuietSessionStillDownloads() {
        let spy = armDiscovery()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.requestBackgroundCheck()

        manager.installPendingUpdate()
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .install)
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(spy.checkCount, 1)
    }

    func testAQueuedManualCheckKeepsItsSpinnerUntilItsOwnSessionAnswers() async {
        let spy = armDiscovery()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.requestBackgroundCheck()
        spy.isInProgress = true
        let checked = expectation(description: "the queued manual check reached the seam")
        spy.onCheckForUpdates = { checked.fulfill() }

        manager.checkForUpdatesManually()
        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertEqual(spy.checkCount, 0)

        let quietChoice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(quietChoice, .dismiss)
        XCTAssertEqual(manager.manualCheckStatus, .checking)

        spy.isInProgress = false
        await fulfillment(of: [checked], timeout: 5)
        XCTAssertEqual(spy.checkCount, 1)

        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(manager.manualCheckStatus, .idle)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testANewerVersionFoundQuietlyKeepsAQueuedManualCheckSpinning() {
        let spy = armDiscovery()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.requestBackgroundCheck()
        spy.isInProgress = true
        manager.checkForUpdatesManually()

        let choice = manager.handleUpdateFound(
            version: "9.9.10", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.10"))
        XCTAssertEqual(manager.manualCheckStatus, .checking)
    }

    func testAManualCheckFromAFailedCardStillOffersTheSameVersion() {
        armDiscovery()
        armFailedCard()

        manager.checkForUpdatesManually()
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testInstallNowStillInstallsTheStagedUpdateAfterLater() {
        armDiscovery()
        armLaterState()

        manager.installNow()
        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .install)
        XCTAssertEqual(manager.phase, .installing)
    }

    // MARK: - Manual check is never swallowed

    func testManualCheckIsNeverThrottled() {
        let spy = armDiscovery()
        manager.popoverDidOpen()

        manager.checkForUpdatesManually()
        manager.checkForUpdatesManually()

        XCTAssertEqual(spy.checkCount, 2)
        XCTAssertEqual(manager.manualCheckStatus, .checking)
    }

    func testManualCheckDuringASilentSessionRunsWhenTheSessionEnds() async {
        let spy = armDiscovery(sessionInProgress: true)
        let checked = expectation(description: "the manual check reached the seam")
        spy.onCheckForUpdates = { checked.fulfill() }

        manager.checkForUpdatesManually()

        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertEqual(spy.checkCount, 0)

        spy.isInProgress = false
        await fulfillment(of: [checked], timeout: 5)

        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertEqual(manager.manualCheckStatus, .checking)

        manager.handleNotFound()

        XCTAssertEqual(manager.manualCheckStatus, .upToDate)
    }

    func testManualCheckGivesUpQuietlyWhenTheSessionNeverEnds() {
        let spy = armDiscovery(sessionInProgress: true)

        manager.checkForUpdatesManually()
        XCTAssertEqual(manager.manualCheckStatus, .checking)

        manager.requestManualCheck(attempt: UpdateManager.resumeCheckMaxAttempts)

        XCTAssertEqual(spy.checkCount, 0)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
        XCTAssertEqual(manager.phase, .idle)
    }

    // MARK: - Update click around a silent session

    func testUpdateClickDuringTheSilentSessionTeardownEndsReadyToInstall() async {
        let spy = armDiscovery(sessionInProgress: true)
        let checked = expectation(description: "the resume check reached the seam")
        spy.onCheckForUpdates = { checked.fulfill() }
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(spy.checkCount, 0)

        spy.isInProgress = false
        await fulfillment(of: [checked], timeout: 5)

        XCTAssertFalse(manager.resumeCheckPending)

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertEqual(choice, .dismiss)
        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testUpdateClickDuringAnArmedInstallResumeStopsAtTheReadyCard() {
        let spy = armDiscovery(sessionInProgress: true)
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .installing, releasePage: nil, informationOnly: false)
        manager.installNow()
        XCTAssertTrue(manager.resumeCheckPending)

        spy.isInProgress = false
        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(manager.resumeRequestCount, 1)
        XCTAssertEqual(spy.checkCount, 0)

        let choice = manager.handleUpdateFound(
            version: "9.9.9", stage: .downloaded, releasePage: nil, informationOnly: false)

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.handleResumeCheckExhausted()

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testUpdateClickDuringARunningDownloadIsIgnored() {
        let spy = armDiscovery(sessionInProgress: true)
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleDownloadInitiated()
        manager.handleDownloadExpectedLength(1_000)
        manager.handleDownloadReceived(bytes: 400)
        XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
        XCTAssertEqual(manager.resumeRequestCount, 1)

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
        XCTAssertFalse(manager.resumeCheckPending)
        XCTAssertEqual(manager.resumeRequestCount, 1)
        XCTAssertEqual(spy.checkCount, 0)
    }

    func testUpdateClickWhileInstallingIsIgnored() {
        armDiscovery(sessionInProgress: true)
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.installPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.handleExtractionStarted()

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .installing)
        XCTAssertFalse(manager.resumeCheckPending)
        XCTAssertEqual(manager.resumeRequestCount, 1)
    }

    func testRetryAfterAFailedDownloadStillStartsTheResumePath() {
        armDiscovery(sessionInProgress: true)
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)
        manager.beginRequestedInstall()
        manager.handleError("download failed")
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))

        manager.installNow()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertTrue(manager.resumeCheckPending)
        XCTAssertEqual(manager.resumeRequestCount, 1)
    }
}
