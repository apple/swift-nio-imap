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

    /// ```
    /// atom-specials   = "(" / ")" / "{" / SP / CTL / list-wildcards / quoted-specials / resp-specials
    /// CTL             = %x00-1F / %x7F   ; RFC 5234
    /// ```
    ///
    /// `isAtomChar`, `isAStringChar` and `isListChar` are all derived from this, so the tests
    /// below share the one set rather than restating it.
    let atomSpecials: Set<UInt8> = Set(0...31).union([
        0x7F,  // CTL — DEL
        UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: " "), UInt8(ascii: "{"),
        UInt8(ascii: "]"),  // ResponseSpecial
        UInt8(ascii: "%"), UInt8(ascii: "*"),  // ListWildcard
        UInt8(ascii: "\""), UInt8(ascii: "\\"),  // QuotedSpecial
    ])

    /// `ATOM-CHAR = <any CHAR except atom-specials>`, and `CHAR = %x01-7F`.
    var atomChars: Set<UInt8> {
        allChars.subtracting(atomSpecials).subtracting(128...UInt8.max)
    }

    @Test("CR")
    func CR() {
        let valid: Set<UInt8> = [UInt8(ascii: "\r")]
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isCR })
        #expect(invalid.allSatisfy { !$0.isCR })
    }

    @Test("LF")
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
        allChars.forEach { char in
            #expect(char.isAtomSpecial == atomSpecials.contains(char))
        }
    }

    /// `ATOM-CHAR = <any CHAR except atom-specials>`
    @Test("atom char")
    func atomChar() {
        // The fences, stated independently of `atomSpecials`: the range runs "!" to "~".
        // Everything from SP down is a CTL or SP, DEL is a CTL, and CHAR stops at %x7F.
        #expect(!UInt8(0x00).isAtomChar)
        #expect(!UInt8(0x1F).isAtomChar)
        #expect(!UInt8(ascii: " ").isAtomChar)
        #expect(UInt8(ascii: "!").isAtomChar)
        #expect(UInt8(ascii: "~").isAtomChar)
        #expect(!UInt8(0x7F).isAtomChar)
        #expect(!UInt8(0x80).isAtomChar)
        #expect(!UInt8(0xFF).isAtomChar)

        let valid = atomChars
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isAtomChar })
        #expect(invalid.allSatisfy { !$0.isAtomChar })
    }

    /// `ASTRING-CHAR = ATOM-CHAR / resp-specials`
    @Test("astring char")
    func aStringChar() {
        let valid = atomChars.union([UInt8(ascii: "]")])
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isAStringChar })
        #expect(invalid.allSatisfy { !$0.isAStringChar })
    }

    /// `list-char = ATOM-CHAR / list-wildcards / resp-specials`
    @Test("list char")
    func listChar() {
        let valid = atomChars.union([UInt8(ascii: "]"), UInt8(ascii: "%"), UInt8(ascii: "*")])
        let invalid = allChars.subtracting(valid)
        #expect(valid.allSatisfy { $0.isListChar })
        #expect(invalid.allSatisfy { !$0.isListChar })
    }

    /// `QUOTED-CHAR = <any TEXT-CHAR except quoted-specials>`
    ///
    /// `TEXT-CHAR` includes DEL and the other C0 controls, so a quoted string may carry bytes
    /// that an atom may not.
    @Test("quoted char")
    func quotedChar() {
        let quotedSpecials: Set<UInt8> = [UInt8(ascii: "\""), UInt8(ascii: "\\")]
        let nonTextChars: Set<UInt8> = [UInt8(ascii: "\r"), UInt8(ascii: "\n"), 0]
        let valid =
            allChars
            .subtracting(quotedSpecials)
            .subtracting(nonTextChars)
            .subtracting(128...UInt8.max)
        let invalid = allChars.subtracting(valid)
        #expect(valid.contains(0x7F))
        #expect(valid.allSatisfy { $0.isQuotedChar })
        #expect(invalid.allSatisfy { !$0.isQuotedChar })
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
