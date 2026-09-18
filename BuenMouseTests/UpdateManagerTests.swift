import Sparkle
import XCTest

@testable import BuenMouse

@MainActor
private final class UpdaterSessionSpy {
    var isInProgress = false
    var checkCount = 0
    var onCheckForUpdates: (() -> Void)?

    var session: UpdateManager.UpdaterSession {
        UpdateManager.UpdaterSession(
            isInProgress: { self.isInProgress },
            checkForUpdates: {
                self.checkCount += 1
                self.onCheckForUpdates?()
            }
        )
    }
}

@MainActor
final class UpdateManagerTests: XCTestCase {

    private var manager: UpdateManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = UpdateManager()
        manager.resumeCheckPollNanoseconds = 1_000
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
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
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
        _ = manager.handleUpdateFound(
            version: "9.9.9", stage: .notDownloaded, releasePage: nil, informationOnly: false)

        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertNil(manager.releasePageURL)
    }
}
