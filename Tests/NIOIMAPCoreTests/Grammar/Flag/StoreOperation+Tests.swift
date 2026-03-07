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

@Suite("StoreOperation")
struct StoreOperationTests {
    @Test("encode", arguments: [
        EncodeFixture.storeOperation(.add, "+"),
        EncodeFixture.storeOperation(.remove, "-"),
        EncodeFixture.storeOperation(.replace, ""),
    ])
    func encode(_ fixture: EncodeFixture<StoreOperation>) {
        fixture.checkEncoding()
    }

    @Test("parse", arguments: [
        ParseFixture.storeOperation("+", expected: .success(.add)),
        ParseFixture.storeOperation("-", expected: .success(.remove)),
        // .replace matches the empty prefix — succeeds on any input without consuming bytes
        ParseFixture.storeOperation("", " ", expected: .success(.replace)),
    ])
    func parse(_ fixture: ParseFixture<StoreOperation>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<StoreOperation> {
    fileprivate static func storeOperation(_ input: StoreOperation, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { buffer, op in buffer.writeString(op.rawValue) }
        )
    }
}

extension ParseFixture<StoreOperation> {
    fileprivate static func storeOperation(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreOperation
        )
    }
}
