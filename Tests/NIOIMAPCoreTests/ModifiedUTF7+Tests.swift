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
    @Test(arguments: [
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
    ])
    func `encode converts strings to Modified UTF-7`(input: String, expected: String) {
        let actual = ModifiedUTF7.encode(input)
        #expect(String(buffer: actual) == expected)
    }

    @Test(arguments: [
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
    ])
    func `decode converts Modified UTF-7 to strings`(input: String, expected: String) throws {
        let actual = try ModifiedUTF7.decode(ByteBuffer(string: input))
        #expect(actual == expected)
    }

    @Test func `decode throws error for invalid Modified UTF-7`() {
        #expect(throws: ModifiedUTF7.OddByteCountError.self) {
            try ModifiedUTF7.decode(ByteBuffer(string: "&aa==-"))
        }
    }

    @Test(arguments: [
        "a",
        "a/b/c",
        "&2Dzf49g83+M-",
        "&ltFO9g-",
    ])
    func `validate accepts valid Modified UTF-7 strings`(input: String) throws {
        try ModifiedUTF7.validate(ByteBuffer(string: input))
    }

    @Test(arguments: [
        "&Jjo!",
        "&U,BTFw-&ZeVnLIqe-",
    ])
    func `validate rejects invalid Modified UTF-7 strings`(input: String) {
        #expect(throws: Error.self) {
            try ModifiedUTF7.validate(ByteBuffer(string: input))
        }
    }
}
