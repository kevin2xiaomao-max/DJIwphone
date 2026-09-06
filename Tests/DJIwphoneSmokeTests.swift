import XCTest
@testable import DJIwphone

final class DJIwphoneSmokeTests: XCTestCase {
    func testOriginalApplicationIdentity() {
        XCTAssertEqual(DJIwphoneIdentity.bundleIdentifier, "com.kevin2xiaomao.qdc507communication")
        XCTAssertEqual(DJIwphoneIdentity.displayName, "DJIwphone")
    }
}
