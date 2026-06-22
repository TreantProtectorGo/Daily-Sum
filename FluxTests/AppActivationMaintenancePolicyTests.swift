import XCTest
@testable import Flux

final class AppActivationMaintenancePolicyTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AppActivationMaintenancePolicyTests")
        defaults.removePersistentDomain(forName: "AppActivationMaintenancePolicyTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AppActivationMaintenancePolicyTests")
        defaults = nil
        super.tearDown()
    }

    func testFirstActivationClaimsMaintenanceRun() {
        let policy = AppActivationMaintenancePolicy(
            defaults: defaults,
            minimumInterval: 15 * 60
        )

        XCTAssertTrue(policy.claimRun(at: Date(timeIntervalSince1970: 1_000)))
    }

    func testRepeatedActivationWithinIntervalSkipsMaintenance() {
        let policy = AppActivationMaintenancePolicy(
            defaults: defaults,
            minimumInterval: 15 * 60
        )
        let firstRun = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(policy.claimRun(at: firstRun))
        XCTAssertFalse(policy.claimRun(at: firstRun.addingTimeInterval(60)))
    }

    func testActivationAfterIntervalClaimsMaintenanceAgain() {
        let policy = AppActivationMaintenancePolicy(
            defaults: defaults,
            minimumInterval: 15 * 60
        )
        let firstRun = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(policy.claimRun(at: firstRun))
        XCTAssertTrue(policy.claimRun(at: firstRun.addingTimeInterval(15 * 60)))
    }

    func testInteractionGracePeriodCanBeConfigured() {
        let policy = AppActivationMaintenancePolicy(
            defaults: defaults,
            minimumInterval: 15 * 60,
            interactionGracePeriod: .milliseconds(750)
        )

        XCTAssertEqual(policy.interactionGracePeriod, .milliseconds(750))
    }
}
