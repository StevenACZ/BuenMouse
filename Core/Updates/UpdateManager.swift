import AppKit
import Combine
import Foundation
import Sparkle
import os

/// In-app updates via Sparkle. The scheduled daily check only surfaces a
/// pending update (update card + About capsule); downloading happens when the
/// user clicks Update, and installing + relaunching when the user then clicks
/// Install now, with progress mirrored in `phase`. Scheduled-check failures
/// stay silent; only a user-requested install surfaces errors.
@MainActor
final class UpdateManager: ObservableObject {

    static let shared = UpdateManager()

    enum Phase: Equatable {
        case idle
        case available(version: String)
        /// nil fraction = size unknown yet (indeterminate spinner).
        case downloading(fraction: Double?)
        case readyToInstall(version: String)
        case installing
        case failed(version: String)
    }

    struct UpdaterSession {
        let isInProgress: @MainActor () -> Bool
        let checkForUpdates: @MainActor () -> Void
    }

    enum ManualCheckStatus: Equatable {
        case idle
        case checking
        case upToDate
    }

    static let autoCheckDefaultsKey = "autoUpdateCheckEnabled"
    /// Local appcast testing only:
    /// `defaults write oliverio23.BuenMouse updateFeedURLOverride <url>`.
    static let feedURLOverrideDefaultsKey = "updateFeedURLOverride"
    static let resumeCheckMaxAttempts = 40

    @Published private(set) var phase: Phase = .idle
    /// GitHub release page of the pending update (the appcast item's <link>).
    @Published private(set) var releasePageURL: URL?
    /// Ephemeral "you're up to date" feedback for the About window.
    @Published private(set) var manualCheckStatus: ManualCheckStatus = .idle
    @Published private(set) var autoCheckEnabled: Bool
    @Published private(set) var pendingVersion: String?
    @Published private(set) var canPostpone = false

    var updaterSession: UpdaterSession?
    var resumeCheckPollNanoseconds: UInt64 = 250_000_000
    private(set) var resumeCheckPending = false
    private(set) var resumeRequestCount = 0

    private let log = Logger(subsystem: "oliverio23.BuenMouse", category: "updates")

    private var updater: SPUUpdater?
    private var driver: Driver?
    private var updaterDelegate: UpdaterDelegate?

    private var installRequested = false
    private var installNowRequested = false
    private var retryRequested = false
    private var pendingInstallReply: ((SPUUserUpdateChoice) -> Void)?
    private var pendingIsInformationOnly = false
    private var expectedDownloadBytes: UInt64 = 0
    private var receivedDownloadBytes: UInt64 = 0
    private var manualCheckPending = false
    private var manualCheckResetTask: Task<Void, Never>?
    private var resumeCheckTask: Task<Void, Never>?

    init() {
        // Defaults to enabled until the Settings toggle writes the key.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.autoCheckDefaultsKey) == nil {
            autoCheckEnabled = true
        } else {
            autoCheckEnabled = defaults.bool(forKey: Self.autoCheckDefaultsKey)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard updater == nil else { return }

        let driver = Driver(manager: self)
        let updaterDelegate = UpdaterDelegate()
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: driver,
            delegate: updaterDelegate
        )
        updater.automaticallyDownloadsUpdates = false
        updater.automaticallyChecksForUpdates = autoCheckEnabled

        do {
            try updater.start()
        } catch {
            log.error("Updater failed to start: \(error.localizedDescription, privacy: .public)")
            return
        }

        self.driver = driver
        self.updaterDelegate = updaterDelegate
        self.updater = updater
        updaterSession = UpdaterSession(
            isInProgress: { updater.sessionInProgress },
            checkForUpdates: { updater.checkForUpdates() }
        )
    }

    func setAutoCheckEnabled(_ enabled: Bool) {
        autoCheckEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoCheckDefaultsKey)
        updater?.automaticallyChecksForUpdates = enabled
    }

    // MARK: - User actions

    /// Update card / About capsule click: download the pending update and stop
    /// at "ready to install". Information-only updates open the release page.
    func installPendingUpdate() {
        guard let updaterSession else { return }
        if pendingIsInformationOnly {
            openReleasePage()
            return
        }
        guard updaterSession.isInProgress() == false else {
            beginRequestedResume(autoInstall: false)
            return
        }
        beginRequestedInstall()
        updaterSession.checkForUpdates()
    }

    func beginRequestedInstall() {
        installRequested = true
        phase = .downloading(fraction: nil)
    }

    func installNow() {
        guard phase != .installing else { return }
        if let pendingInstallReply {
            self.pendingInstallReply = nil
            canPostpone = false
            installRequested = true
            retryRequested = false
            phase = .installing
            pendingInstallReply(.install)
            return
        }
        guard updaterSession != nil else { return }
        if case .failed = phase {
            beginRequestedResume(autoInstall: false, retry: true)
            return
        }
        beginRequestedResume()
    }

    func installLater() {
        guard let pendingInstallReply else { return }
        self.pendingInstallReply = nil
        canPostpone = false
        installRequested = false
        retryRequested = false
        pendingInstallReply(.dismiss)
    }

    func beginRequestedResume(autoInstall: Bool = true, retry: Bool = false) {
        installRequested = true
        installNowRequested = autoInstall
        retryRequested = retry
        resumeCheckPending = true
        phase = autoInstall ? .installing : .downloading(fraction: nil)
        resumeRequestCount += 1
        resumeCheckTask?.cancel()
        requestResumeCheck(attempt: 0)
    }

    /// Sparkle refuses a check while the aborting session is still tearing
    /// down; retry briefly instead of leaving the card stuck on "installing".
    private func requestResumeCheck(attempt: Int) {
        guard resumeCheckPending, let updaterSession else { return }
        guard updaterSession.isInProgress() else {
            resumeCheckPending = false
            updaterSession.checkForUpdates()
            return
        }
        guard attempt < Self.resumeCheckMaxAttempts else {
            handleResumeCheckExhausted()
            return
        }
        resumeCheckTask = Task { [weak self, interval = resumeCheckPollNanoseconds] in
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { return }
            self?.requestResumeCheck(attempt: attempt + 1)
        }
    }

    /// The prepared update never became resumable; drop the install consent
    /// so no later scheduled check installs unattended.
    func handleResumeCheckExhausted() {
        guard resumeCheckPending else { return }
        installRequested = false
        installNowRequested = false
        retryRequested = false
        resumeCheckPending = false
        phase = .failed(version: pendingVersion ?? "")
    }

    /// About window: explicit re-check with visible "up to date" feedback.
    func checkForUpdatesManually() {
        guard let updater, updater.sessionInProgress == false else { return }
        manualCheckResetTask?.cancel()
        manualCheckPending = true
        manualCheckStatus = .checking
        updater.checkForUpdates()
    }

    func openReleasePage() {
        guard let releasePageURL else { return }
        NSWorkspace.shared.open(releasePageURL)
    }

    // MARK: - Driver events (pure state transitions, unit-testable)

    func handleUpdateFound(
        version: String,
        stage: SPUUserUpdateStage,
        releasePage: URL?,
        informationOnly: Bool
    ) -> SPUUserUpdateChoice {
        resumeCheckPending = false
        pendingVersion = version
        pendingIsInformationOnly = informationOnly
        releasePageURL = releasePage
        finishManualCheck(status: .idle)

        guard stage == .notDownloaded else {
            if (installRequested || installNowRequested) && !informationOnly && !retryRequested {
                phase = .installing
                return .install
            }
            installRequested = false
            installNowRequested = false
            retryRequested = false
            phase = .readyToInstall(version: version)
            return .dismiss
        }

        installNowRequested = false
        if installRequested && !informationOnly {
            phase = .downloading(fraction: nil)
            return .install
        }
        installRequested = false
        phase = .available(version: version)
        return .dismiss
    }

    func handleDownloadInitiated() {
        expectedDownloadBytes = 0
        receivedDownloadBytes = 0
        phase = .downloading(fraction: nil)
    }

    func handleDownloadExpectedLength(_ length: UInt64) {
        expectedDownloadBytes = length
    }

    func handleDownloadReceived(bytes: UInt64) {
        receivedDownloadBytes += bytes
        guard expectedDownloadBytes > 0 else { return }
        let fraction = min(1.0, Double(receivedDownloadBytes) / Double(expectedDownloadBytes))
        phase = .downloading(fraction: fraction)
    }

    func handleExtractionStarted() {
        phase = .installing
    }

    func handleReadyToInstall(reply: @escaping (SPUUserUpdateChoice) -> Void) {
        resumeCheckPending = false
        if installNowRequested {
            installNowRequested = false
            phase = .installing
            reply(.install)
            return
        }
        retryRequested = false
        pendingInstallReply = reply
        canPostpone = true
        phase = .readyToInstall(version: pendingVersion ?? "")
    }

    func handleInstalling() {
        phase = .installing
    }

    func handleNotFound() {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            canPostpone = false
            return
        }
        installRequested = false
        installNowRequested = false
        retryRequested = false
        pendingInstallReply = nil
        canPostpone = false
        pendingVersion = nil
        pendingIsInformationOnly = false
        releasePageURL = nil
        phase = .idle
        finishManualCheck(status: .upToDate)
    }

    /// Scheduled-check errors stay silent; a user-requested install shows
    /// a retryable failure row instead.
    func handleError(_ message: String) {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            canPostpone = false
            return
        }
        finishManualCheck(status: .idle)
        installNowRequested = false
        retryRequested = false
        pendingInstallReply = nil
        canPostpone = false
        if installRequested, let pendingVersion {
            log.error("Update install failed: \(message, privacy: .public)")
            phase = .failed(version: pendingVersion)
        } else {
            log.debug("Update check failed silently")
            switch phase {
            case .readyToInstall, .installing:
                phase = .readyToInstall(version: pendingVersion ?? "")
            case .idle, .available, .downloading, .failed:
                phase = pendingVersion.map { .available(version: $0) } ?? .idle
            }
        }
        installRequested = false
    }

    /// Sparkle tears the session down (abort or completion). Keep the pending
    /// row alive; only roll back an unfinished download, a prepared update
    /// stays offered as ready to install. The install consent dies with the
    /// session so no later scheduled check installs unattended.
    func handleDismissInstallation() {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            canPostpone = false
            return
        }
        switch phase {
        case .downloading:
            phase = pendingVersion.map { .available(version: $0) } ?? .idle
        case .installing, .readyToInstall:
            phase = .readyToInstall(version: pendingVersion ?? "")
        case .idle, .available, .failed:
            break
        }
        installRequested = false
        installNowRequested = false
        retryRequested = false
        pendingInstallReply = nil
        canPostpone = false
    }

    private func finishManualCheck(status: ManualCheckStatus) {
        guard manualCheckPending else { return }
        manualCheckPending = false
        manualCheckStatus = status
        guard status != .idle else { return }
        manualCheckResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.manualCheckStatus = .idle
        }
    }
}

// MARK: - Sparkle user driver

/// Bridges Sparkle's user-interaction callbacks onto the manager's phase.
/// Every callback arrives on the main actor (the protocol is NS_SWIFT_UI_ACTOR).
@MainActor
private final class Driver: NSObject, SPUUserDriver {

    private unowned let manager: UpdateManager

    init(manager: UpdateManager) {
        self.manager = manager
    }

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        // Unreached: SUEnableAutomaticChecks in Info.plist suppresses the prompt.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let choice = manager.handleUpdateFound(
            version: appcastItem.displayVersionString,
            stage: state.stage,
            releasePage: appcastItem.infoURL,
            informationOnly: appcastItem.isInformationOnlyUpdate
        )
        reply(choice)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        manager.handleNotFound()
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        manager.handleError(error.localizedDescription)
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        manager.handleDownloadInitiated()
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        manager.handleDownloadExpectedLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        manager.handleDownloadReceived(bytes: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        manager.handleExtractionStarted()
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        manager.handleReadyToInstall(reply: reply)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        manager.handleInstalling()
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        manager.handleDismissInstallation()
    }
}

// MARK: - Sparkle updater delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

    /// Local-testing escape hatch: point the feed at a local appcast.
    /// Production resolves SUFeedURL from Info.plist (return nil).
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: UpdateManager.feedURLOverrideDefaultsKey)
    }
}
