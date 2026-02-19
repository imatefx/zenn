import XCTest
@testable import ZennShared

final class WindowRuleTests: XCTestCase {

    func testMatchByAppName() {
        let rule = WindowRule(appNamePattern: "Finder")
        XCTAssertTrue(rule.matches(appName: "Finder", title: "Home", bundleID: "com.apple.finder"))
        XCTAssertFalse(rule.matches(appName: "Safari", title: "Home", bundleID: "com.apple.safari"))
    }

    func testMatchByRegex() {
        let rule = WindowRule(appNamePattern: "^System.*")
        XCTAssertTrue(rule.matches(appName: "System Settings", title: "", bundleID: ""))
        XCTAssertTrue(rule.matches(appName: "System Information", title: "", bundleID: ""))
        XCTAssertFalse(rule.matches(appName: "Finder", title: "", bundleID: ""))
    }

    func testMatchByTitle() {
        let rule = WindowRule(titlePattern: "Copy")
        XCTAssertTrue(rule.matches(appName: "Finder", title: "Copy 3 items", bundleID: ""))
        XCTAssertFalse(rule.matches(appName: "Finder", title: "Home", bundleID: ""))
    }

    func testMatchByBundleID() {
        let rule = WindowRule(bundleID: "com.apple.finder")
        XCTAssertTrue(rule.matches(appName: "Finder", title: "", bundleID: "com.apple.finder"))
        XCTAssertFalse(rule.matches(appName: "Finder", title: "", bundleID: "com.apple.safari"))
    }

    func testMultipleConditions() {
        let rule = WindowRule(appNamePattern: "Finder", titlePattern: "Copy")
        XCTAssertTrue(rule.matches(appName: "Finder", title: "Copy 3 items", bundleID: ""))
        XCTAssertFalse(rule.matches(appName: "Finder", title: "Home", bundleID: ""))
        XCTAssertFalse(rule.matches(appName: "Safari", title: "Copy", bundleID: ""))
    }

    func testEmptyRuleMatchesAll() {
        let rule = WindowRule()
        XCTAssertTrue(rule.matches(appName: "Anything", title: "Whatever", bundleID: "com.test"))
    }

    func testCaseInsensitiveMatch() {
        let rule = WindowRule(appNamePattern: "finder")
        XCTAssertTrue(rule.matches(appName: "Finder", title: "", bundleID: ""))
    }
}
