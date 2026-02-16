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

@Suite("MetadataOption")
struct MetadataOptionTests {
    @Test(arguments: [
        EncodeFixture.metadataOption(
            .maxSize(123),
            "MAXSIZE 123"
        ),
        EncodeFixture.metadataOption(
            .scope(.one),
            "DEPTH 1"
        ),
        EncodeFixture.metadataOption(
            .other(.init(key: "param", value: nil)),
            "param"
        ),
    ])
    func `encodes single metadata option`(_ fixture: EncodeFixture<MetadataOption>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.metadataOptions(
            [.maxSize(123)],
            "(MAXSIZE 123)"
        ),
        EncodeFixture.metadataOptions(
            [.maxSize(1), .scope(.one)],
            "(MAXSIZE 1 DEPTH 1)"
        ),
    ])
    func `encodes array of metadata options`(_ fixture: EncodeFixture<[MetadataOption]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.metadataOption("MAXSIZE 123", expected: .success(.maxSize(123))),
        ParseFixture.metadataOption("DEPTH 1", expected: .success(.scope(.one))),
        ParseFixture.metadataOption("param", expected: .success(.other(.init(key: "param", value: nil)))),
    ])
    func `parse metadata option`(_ fixture: ParseFixture<MetadataOption>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.metadataOptions("(MAXSIZE 123)", expected: .success([.maxSize(123)])),
        ParseFixture.metadataOptions("(DEPTH 1 MAXSIZE 123)", expected: .success([.scope(.one), .maxSize(123)])),
    ])
    func `parse metadata options`(_ fixture: ParseFixture<[MetadataOption]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MetadataOption> {
    fileprivate static func metadataOption(
        _ input: MetadataOption,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMetadataOption($1) }
        )
    }
}

extension EncodeFixture<[MetadataOption]> {
    fileprivate static func metadataOptions(
        _ input: [MetadataOption],
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMetadataOptions($1) }
        )
    }
}

extension ParseFixture<MetadataOption> {
    fileprivate static func metadataOption(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMetadataOption
        )
    }
}

extension ParseFixture<[MetadataOption]> {
    fileprivate static func metadataOptions(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMetadataOptions
        )
    }
}
