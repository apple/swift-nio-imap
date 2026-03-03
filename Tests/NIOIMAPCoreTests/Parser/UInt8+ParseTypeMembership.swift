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
import Testing

@Suite("UInt8 Parse Type Membership")
struct UInt8ParseTypeMembershipTests {
    let allChars = Set(UInt8.min...UInt8.max)

    @Test
    func CR() {
        let valid: Set<UInt8> = [UInt8(ascii: "\r")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isCR })
        #expect(invalid.allSatisfy { !$0.isCR })
    }

    @Test
    func LF() {
        let valid: Set<UInt8> = [UInt8(ascii: "\n")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isLF })
        #expect(invalid.allSatisfy { !$0.isLF })
    }

    @Test("response special")
    func responseSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "]")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isResponseSpecial })
        #expect(invalid.allSatisfy { !$0.isResponseSpecial })
    }

    @Test("list wildcard")
    func listWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isListWildcard })
        #expect(invalid.allSatisfy { !$0.isListWildcard })
    }

    @Test("quoted special")
    func quotedSpecial() {
        let valid: Set<UInt8> = [UInt8(ascii: "\\"), UInt8(ascii: "\"")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isQuotedSpecial })
        #expect(invalid.allSatisfy { !$0.isQuotedSpecial })
    }

    @Test("atom special")
    func atomSpecial() {
        var valid: Set<UInt8> = [
            UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: " "), UInt8(ascii: "{"),
            UInt8(ascii: "]"),  // ResponseSpecial
            UInt8(ascii: "%"), UInt8(ascii: "*"),  // ListWildcard
            UInt8(ascii: "\""), UInt8(ascii: "\\"),  // QuotedSpecial
        ]
        valid = valid.union(0...31)
        allChars.forEach { char in
            if valid.contains(char) {
                #expect(char.isAtomSpecial)
            } else {
                #expect(!char.isAtomSpecial)
            }
        }
    }

    @Test("text char")
    func textChar() {
        // thanks Johannes
        let invalid: Set<UInt8> = [UInt8(ascii: "\r"), .init(ascii: "\n"), 0]
        let valid = allChars.subtracting(invalid).subtracting(128...UInt8.max)
        #expect(valid.allSatisfy { $0.isTextChar })
        #expect(invalid.allSatisfy { !$0.isTextChar })
    }

    @Test("hex character")
    func hexCharacter() {
        var valid = Set<UInt8>()
        valid = valid.union(UInt8(ascii: "0")...UInt8(ascii: "9"))
        valid = valid.union(UInt8(ascii: "a")...UInt8(ascii: "f"))
        valid = valid.union(UInt8(ascii: "A")...UInt8(ascii: "F"))

        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isHexCharacter })
        #expect(invalid.allSatisfy { !$0.isHexCharacter })
    }

    @Test("base64 character")
    func base64Character() {
        var valid = Set<UInt8>()
        valid = valid.union(UInt8(ascii: "0")...UInt8(ascii: "9"))
        valid = valid.union(UInt8(ascii: "a")...UInt8(ascii: "z"))
        valid = valid.union(UInt8(ascii: "A")...UInt8(ascii: "Z"))
        valid = valid.union([UInt8(ascii: "+"), UInt8(ascii: "/")])

        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isBase64Char })
        #expect(invalid.allSatisfy { !$0.isBase64Char })
    }
}
