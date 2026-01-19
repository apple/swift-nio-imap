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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("BodyStructure.Disposition")
struct BodyFieldDSPTests {
    @Test(arguments: [
        EncodeFixture<BodyStructure.Disposition?>.bodyDisposition(
            nil, "NIL"
        ),
        EncodeFixture<BodyStructure.Disposition?>.bodyDisposition(
            .init(kind: "some", parameters: ["f1": "v1"]), "(\"some\" (\"f1\" \"v1\"))"
        ),
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.Disposition?>) {
        fixture.checkEncoding()
    }

    struct SizeFixture: Sendable, CustomTestStringConvertible {
        var name: String
        var disposition: BodyStructure.Disposition
        var expected: Int?

        var testDescription: String { name }
    }

    @Test(arguments: [
        SizeFixture(name: "no size parameter", disposition: .init(kind: "test", parameters: [:]), expected: nil),
        SizeFixture(name: "lowercase size parameter", disposition: .init(kind: "test", parameters: ["size": "123"]), expected: 123),
        SizeFixture(name: "uppercase SIZE parameter", disposition: .init(kind: "test", parameters: ["SIZE": "456"]), expected: 456),
        SizeFixture(name: "invalid size value", disposition: .init(kind: "test", parameters: ["SIZE": "abc"]), expected: nil),
    ])
    func sizeProperty(_ fixture: SizeFixture) {
        #expect(fixture.disposition.size == fixture.expected)
    }

    struct FilenameFixture: Sendable, CustomTestStringConvertible {
        var name: String
        var disposition: BodyStructure.Disposition
        var expected: String?

        var testDescription: String { name }
    }

    @Test(arguments: [
        FilenameFixture(name: "no filename parameter", disposition: .init(kind: "test", parameters: [:]), expected: nil),
        FilenameFixture(name: "lowercase filename parameter", disposition: .init(kind: "test", parameters: ["filename": "hello"]), expected: "hello"),
        FilenameFixture(name: "uppercase FILENAME parameter", disposition: .init(kind: "test", parameters: ["FILENAME": "world"]), expected: "world"),
    ])
    func filenameProperty(_ fixture: FilenameFixture) {
        #expect(fixture.disposition.filename == fixture.expected)
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.Disposition?> {
    fileprivate static func bodyDisposition(
        _ input: BodyStructure.Disposition?,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyDisposition($1) }
        )
    }
}
