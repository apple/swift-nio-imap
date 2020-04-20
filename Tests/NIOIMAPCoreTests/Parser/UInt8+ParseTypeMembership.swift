//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest
@testable import NIOIMAPCore

final class UInt8ParseTypeMembershipTests: XCTestCase {

    let allChars = Set(UInt8.min ... UInt8.max)
    
}

// MARK: - test isCR
extension UInt8ParseTypeMembershipTests {
    
    func testCR() {
        let valid: Set<UInt8> = [UInt8(ascii: "\r")]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isCR })
        XCTAssertTrue(invalid.allSatisfy { !$0.isCR })
    }
    
}

// MARK: - test isLF
extension UInt8ParseTypeMembershipTests {
    
    func testLF() {
        let valid: Set<UInt8> = [UInt8(ascii: "\n")]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isLF })
        XCTAssertTrue(invalid.allSatisfy { !$0.isLF })
    }
    
}

// MARK: - test isResponseSpecial
extension UInt8ParseTypeMembershipTests {
    
    func testResponseSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "]")]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isResponseSpecial })
        XCTAssertTrue(invalid.allSatisfy { !$0.isResponseSpecial })
    }
    
}

// MARK: - test isListWildcard
extension UInt8ParseTypeMembershipTests {
    
    func testListWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isListWildcard })
        XCTAssertTrue(invalid.allSatisfy { !$0.isListWildcard })
    }
    
}

// MARK: - test isQuotedSpecial
extension UInt8ParseTypeMembershipTests {
    
    func testQuotedSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "\\"), UInt8(ascii: "\"")]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isQuotedSpecial })
        XCTAssertTrue(invalid.allSatisfy { !$0.isQuotedSpecial })
    }
    
}

// MARK: - test isAtomSpecial
extension UInt8ParseTypeMembershipTests {
    
    func testAtomSpecial() {
        let valid: Set<UInt8> = [
            UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: "^"), UInt8(ascii: " "),
            UInt8(ascii: "]"), // ResponseSpecial
            UInt8(ascii: "%"), UInt8(ascii: "*"), // ListWildcard
            UInt8(ascii: "\""), UInt8(ascii: "\\"), // QuotedSpecial
        ]
        let invalid = allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isAtomSpecial })
        XCTAssertTrue(invalid.allSatisfy { !$0.isAtomSpecial })
    }
    
}

// MARK: - test isTextChar
extension UInt8ParseTypeMembershipTests {
    
    // thanks Johannes
    func testTextChar() {
        let invalid: Set<UInt8> = [UInt8(ascii: "\r"), .init(ascii: "\n"), 0]
        let valid = allChars.subtracting(invalid)
        XCTAssertTrue(valid.allSatisfy { $0.isTextChar })
        XCTAssertTrue(invalid.allSatisfy { !$0.isTextChar })
    }
    
}
