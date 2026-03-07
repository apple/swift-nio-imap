//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("ObjectID")
struct ObjectIDTests {
    @Test(arguments: [
        EncodeFixture.objectID(ObjectID("abc123")!, "abc123"),
        EncodeFixture.objectID(ObjectID("M1-abc_XY")!, "M1-abc_XY"),
    ])
    func encode(_ fixture: EncodeFixture<ObjectID>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.objectID("abc123", expected: .success(ObjectID("abc123")!)),
        ParseFixture.objectID("M1-abc_XY", expected: .success(ObjectID("M1-abc_XY")!)),
        ParseFixture.objectID("", "", expected: .failure),
        ParseFixture.objectID(String(repeating: "a", count: 256), " ", expected: .failureIgnoringBufferModifications),
    ])
    func parse(_ fixture: ParseFixture<ObjectID>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ObjectID> {
    fileprivate static func objectID(_ input: ObjectID, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeObjectID($1) }
        )
    }
}

extension ParseFixture<ObjectID> {
    fileprivate static func objectID(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseObjectID
        )
    }
}
