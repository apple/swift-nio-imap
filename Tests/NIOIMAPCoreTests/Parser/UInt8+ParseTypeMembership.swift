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

@testable import NIOIMAPCore
import XCTest

final class UInt8ParseTypeMembershipTests: XCTestCase {
    let allChars = Set(UInt8.min ... UInt8.max)
}

// MARK: - test isCR

extension UInt8ParseTypeMembershipTests {
    func testCR() {
        let valid: Set<UInt8> = [UInt8(ascii: "\r")]
        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isCR })
        XCTAssertTrue(invalid.allSatisfy { !$0.isCR })
    }
}

// MARK: - test isLF

extension UInt8ParseTypeMembershipTests {
    func testLF() {
        let valid: Set<UInt8> = [UInt8(ascii: "\n")]
        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isLF })
        XCTAssertTrue(invalid.allSatisfy { !$0.isLF })
    }
}

// MARK: - test isResponseSpecial

extension UInt8ParseTypeMembershipTests {
    func testResponseSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "]")]
        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isResponseSpecial })
        XCTAssertTrue(invalid.allSatisfy { !$0.isResponseSpecial })
    }
}

// MARK: - test isListWildcard

extension UInt8ParseTypeMembershipTests {
    func testListWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isListWildcard })
        XCTAssertTrue(invalid.allSatisfy { !$0.isListWildcard })
    }
}

// MARK: - test isQuotedSpecial

extension UInt8ParseTypeMembershipTests {
    func testQuotedSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "\\"), UInt8(ascii: "\"")]
        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isQuotedSpecial })
        XCTAssertTrue(invalid.allSatisfy { !$0.isQuotedSpecial })
    }
}

// MARK: - test isAtomSpecial

extension UInt8ParseTypeMembershipTests {
    func testAtomSpecial() {
        var valid: Set<UInt8> = [
            UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: " "), UInt8(ascii: "{"),
            UInt8(ascii: "]"), // ResponseSpecial
            UInt8(ascii: "%"), UInt8(ascii: "*"), // ListWildcard
            UInt8(ascii: "\""), UInt8(ascii: "\\"), // QuotedSpecial
        ]
        valid = valid.union(0...31)
        self.allChars.forEach { char in
            if valid.contains(char) {
                XCTAssertTrue(char.isAtomSpecial)
            } else {
                XCTAssertFalse(char.isAtomSpecial)
            }
        }
    }
}

// MARK: - test isTextChar

extension UInt8ParseTypeMembershipTests {
    // thanks Johannes
    func testTextChar() {
        let invalid: Set<UInt8> = [UInt8(ascii: "\r"), .init(ascii: "\n"), 0]
        let valid = self.allChars.subtracting(invalid).subtracting(128 ... UInt8.max)
        XCTAssertTrue(valid.allSatisfy { $0.isTextChar })
        XCTAssertTrue(invalid.allSatisfy { !$0.isTextChar })
    }
}

// MARK: - test isHexChar

extension UInt8ParseTypeMembershipTests {
    func testHexCharacter() {
        var valid = Set<UInt8>()
        valid = valid.union(UInt8(ascii: "0") ... UInt8(ascii: "9"))
        valid = valid.union(UInt8(ascii: "a") ... UInt8(ascii: "f"))
        valid = valid.union(UInt8(ascii: "A") ... UInt8(ascii: "F"))

        let invalid = self.allChars.subtracting(valid)
        XCTAssertTrue(valid.allSatisfy { $0.isHexCharacter })
        XCTAssertTrue(invalid.allSatisfy { !$0.isHexCharacter })
    }
}
