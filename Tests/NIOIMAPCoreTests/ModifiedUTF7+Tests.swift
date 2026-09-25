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

import NIO
@testable import NIOIMAPCore
import Testing

@Suite("ModifiedUTF7")
struct ModifiedUTF7Tests {
    @Test(
        "encode converts strings to Modified UTF-7",
        arguments: [
            ("", ""),
            ("abc", "abc"),
            ("&", "&-"),
            ("ab&12", "ab&-12"),
            ("mail/€/£", "mail/&IKw-/&AKM-"),
            ("Répertoire", "R&AOk-pertoire"),
            ("パリ", "&MNEw6g-"),
            ("雑件", "&ltFO9g-"),
            ("🏣🏣", "&2Dzf49g83+M-"),
            ("🧑🏽‍🦳", "&2D7d0dg83,0gDdg+3bM-"),
            ("a/b/c", "a/b/c"),
            (#"a\b\c"#, #"a\b\c"#),
            ("a+b", "a+b"),
            ("~ab", "~ab"),
            // Printable ASCII is 0x20–0x7E; 0x1F and 0x7F must be Base64.
            ("a b", "a b"),
            ("\u{1F}", "&AB8-"),
            ("\u{7F}", "&AH8-"),
            ("é\u{1F}", "&AOkAHw-"),
            ("é\u{7F}", "&AOkAfw-"),
        ]
    )
    func encodeConvertsStringsToModifiedUTF7(input: String, expected: String) {
        let actual = ModifiedUTF7.encode(input)
        #expect(String(buffer: actual) == expected)
    }

    @Test(
        "decode converts Modified UTF-7 to strings",
        arguments: [
            ("", ""),
            ("abc", "abc"),
            ("&-", "&"),
            ("ab&-12", "ab&12"),
            ("mail/&IKw-/&AKM-", "mail/€/£"),
            ("R&AOk-pertoire", "Répertoire"),
            ("&MNEw6g-", "パリ"),
            ("&ltFO9g-", "雑件"),
            ("&2Dzf49g83+M-", "🏣🏣"),
            ("&2D7d0dg83,0gDdg+3bM-", "🧑🏽‍🦳"),
            ("a/b/c", "a/b/c"),
            (#"a\b\c"#, #"a\b\c"#),
            ("a+b", "a+b"),
            ("~ab", "~ab"),
            ("a b", "a b"),
            ("&AB8-", "\u{1F}"),
            ("&AH8-", "\u{7F}"),
            ("&AOkAHw-", "é\u{1F}"),
            ("&AOkAfw-", "é\u{7F}"),
        ]
    )
    func decodeConvertsModifiedUTF7ToStrings(input: String, expected: String) throws {
        let actual = try ModifiedUTF7.decode(ByteBuffer(string: input))
        #expect(actual == expected)
    }

    @Test("decode throws error for invalid Modified UTF-7")
    func decodeThrowsErrorForInvalidModifiedUTF7() {
        #expect(throws: ModifiedUTF7.OddByteCountError.self) {
            try ModifiedUTF7.decode(ByteBuffer(string: "&aa==-"))
        }
    }

    @Test(
        "validate accepts valid Modified UTF-7 strings",
        arguments: [
            "a",
            "a/b/c",
            "&2Dzf49g83+M-",
            "&ltFO9g-",
        ]
    )
    func validateAcceptsValidModifiedUTF7Strings(input: String) throws {
        try ModifiedUTF7.validate(ByteBuffer(string: input))
    }

    @Test(
        "validate rejects invalid Modified UTF-7 strings",
        arguments: [
            "&Jjo!",
            "&U,BTFw-&ZeVnLIqe-",
        ]
    )
    func validateRejectsInvalidModifiedUTF7Strings(input: String) {
        #expect(throws: Error.self) {
            try ModifiedUTF7.validate(ByteBuffer(string: input))
        }
    }
}
