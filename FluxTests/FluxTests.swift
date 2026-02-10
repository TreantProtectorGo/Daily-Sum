//
//  FluxTests.swift
//  FluxTests
//
//  Created by Wing - on 9/2/2026.
//

import XCTest
@testable import Flux

final class FluxTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTransactionAccountPreferencePersistsValues() throws {
        let originalDefaultAccountId = TransactionAccountPreference.defaultAccountId
        let originalRememberLastUsed = TransactionAccountPreference.rememberLastUsedAccount
        let originalLastUsedAccountId = TransactionAccountPreference.lastUsedAccountId
        
        defer {
            TransactionAccountPreference.defaultAccountId = originalDefaultAccountId
            TransactionAccountPreference.rememberLastUsedAccount = originalRememberLastUsed
            TransactionAccountPreference.lastUsedAccountId = originalLastUsedAccountId
        }
        
        let accountId = UUID()
        
        TransactionAccountPreference.defaultAccountId = accountId
        TransactionAccountPreference.rememberLastUsedAccount = true
        TransactionAccountPreference.lastUsedAccountId = accountId
        
        XCTAssertEqual(TransactionAccountPreference.defaultAccountId, accountId)
        XCTAssertTrue(TransactionAccountPreference.rememberLastUsedAccount)
        XCTAssertEqual(TransactionAccountPreference.lastUsedAccountId, accountId)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
