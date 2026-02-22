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

@Suite("ConditionalStoreParameter")
struct ConditionalStoreTests {
    @Test("encodes to CONDSTORE")
    func encodesToCondstore() {
        let expected = "CONDSTORE"
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let size = buffer.writeConditionalStoreParameter()
        #expect(size == expected.utf8.count)
        let chunk = buffer.nextChunk()
        #expect(String(buffer: chunk.bytes) == expected)
    }

    @Test(arguments: [
        ParseFixture.conditionalStoreParameter("condstore", " ", expected: .success(Dummy())),
        ParseFixture.conditionalStoreParameter("CONDSTORE", " ", expected: .success(Dummy())),
        ParseFixture.conditionalStoreParameter("condSTORE", " ", expected: .success(Dummy())),
    ])
    fileprivate func parse(_ fixture: ParseFixture<Dummy>) {
        fixture.checkParsing()
    }
}

@Suite("LastCommandSet (RFC 5182)")
struct LastCommandSetRFC5182Tests {
    @Test(arguments: [
        EncodeFixture.lastCommandSet(.lastCommand, "$"),
        EncodeFixture.lastCommandSet(.range(UID(1)...UID(3)), "1:3"),
        EncodeFixture.lastCommandSet(.set(.init(range: .init(UID(5)))), "5"),
    ])
    func encode(_ fixture: EncodeFixture<LastCommandSet<UID>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.lastCommandSet("$", expected: .success(.lastCommand)),
        ParseFixture.lastCommandSet("1:3", expected: .success(.range(UID(1)...UID(3)))),
        ParseFixture.lastCommandSet("5", expected: .success(.set(.init(range: .init(UID(5)))))),
        ParseFixture.lastCommandSet("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<LastCommandSet<UID>>) {
        fixture.checkParsing()
    }
}

@Suite("LastCommandMessageID (RFC 5182)")
struct LastCommandMessageIDRFC5182Tests {
    @Test(arguments: [
        EncodeFixture.lastCommandMessageID(.lastCommand, "$"),
        EncodeFixture.lastCommandMessageID(.id(UID(42)), "42"),
    ])
    func encode(_ fixture: EncodeFixture<LastCommandMessageID<UID>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.lastCommandMessageID("$", expected: .success(.lastCommand)),
        ParseFixture.lastCommandMessageID("42", expected: .success(.id(UID(42)))),
        ParseFixture.lastCommandMessageID("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<LastCommandMessageID<UID>>) {
        fixture.checkParsing()
    }
}

@Suite("StoreModifier")
struct StoreModifierTests {
    @Test(arguments: [
        EncodeFixture.storeModifier(
            .unchangedSince(.init(modificationSequence: 12345)),
            "UNCHANGEDSINCE 12345"
        ),
        EncodeFixture.storeModifier(
            .other(.init(key: "MYEXT", value: nil)),
            "MYEXT"
        ),
    ])
    func encode(_ fixture: EncodeFixture<StoreModifier>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.storeModifier("UNCHANGEDSINCE 12345", expected: .success(.unchangedSince(.init(modificationSequence: 12345)))),
        ParseFixture.storeModifier("MYEXT", ")", expected: .success(.other(.init(key: "MYEXT", value: nil)))),
        ParseFixture.storeModifier("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<StoreModifier>) {
        fixture.checkParsing()
    }
}

@Suite("StoreModifiers (array)")
struct StoreModifiersTests {
    @Test(arguments: [
        EncodeFixture.storeModifiers(
            [.unchangedSince(.init(modificationSequence: 99))],
            " (UNCHANGEDSINCE 99)"
        ),
        EncodeFixture.storeModifiers([], ""),
    ])
    func encode(_ fixture: EncodeFixture<[StoreModifier]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.storeModifiers(" (UNCHANGEDSINCE 42)", expected: .success([.unchangedSince(.init(modificationSequence: 42))])),
        ParseFixture.storeModifiers("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<[StoreModifier]>) {
        fixture.checkParsing()
    }
}

// MARK: -

/// `Void` / `nil` replacement that is `Equatable`.
private struct Dummy: Equatable {}

extension ParseFixture<Dummy> {
    fileprivate static func conditionalStoreParameter(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                try GrammarParser().parseConditionalStoreParameter(buffer: &$0, tracker: $1)
                return Dummy()
            }
        )
    }
}

extension EncodeFixture<LastCommandSet<UID>> {
    fileprivate static func lastCommandSet(_ input: LastCommandSet<UID>, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeLastCommandSet($1) }
        )
    }
}

extension ParseFixture<LastCommandSet<UID>> {
    fileprivate static func lastCommandSet(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: { buffer, tracker in
                try GrammarParser().parseLastCommandSet(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: GrammarParser().parseUIDSetNonEmpty
                )
            }
        )
    }
}

extension EncodeFixture<LastCommandMessageID<UID>> {
    fileprivate static func lastCommandMessageID(
        _ input: LastCommandMessageID<UID>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeLastCommandMessageID($1) }
        )
    }
}

extension ParseFixture<LastCommandMessageID<UID>> {
    fileprivate static func lastCommandMessageID(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: { buffer, tracker in
                try GrammarParser().parseLastCommandMessageID(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: GrammarParser().parseMessageIdentifier
                )
            }
        )
    }
}

extension EncodeFixture<StoreModifier> {
    fileprivate static func storeModifier(_ input: StoreModifier, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeStoreModifier($1) }
        )
    }
}

extension ParseFixture<StoreModifier> {
    fileprivate static func storeModifier(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreModifier
        )
    }
}

extension EncodeFixture<[StoreModifier]> {
    fileprivate static func storeModifiers(_ input: [StoreModifier], _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeStoreModifiers($1) }
        )
    }
}

extension ParseFixture<[StoreModifier]> {
    fileprivate static func storeModifiers(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreModifiers
        )
    }
}
