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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ListSelectOption")
struct ListSelectOptionTests {
    @Test(arguments: [
        EncodeFixture.listSelectOption(.subscribed, "SUBSCRIBED"),
        EncodeFixture.listSelectOption(.remote, "REMOTE"),
        EncodeFixture.listSelectOption(.recursiveMatch, "RECURSIVEMATCH"),
        EncodeFixture.listSelectOption(.specialUse, "SPECIAL-USE"),
    ])
    func `encode single option`(_ fixture: EncodeFixture<ListSelectOption>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.listSelectOptions(nil, "()"),
        EncodeFixture.listSelectOptions(.init(baseOption: .subscribed, options: [.subscribed]), "(SUBSCRIBED SUBSCRIBED)"),
        EncodeFixture.listSelectOptions(.init(baseOption: .subscribed, options: [.specialUse, .recursiveMatch]), "(SPECIAL-USE RECURSIVEMATCH SUBSCRIBED)"),
    ])
    func `encode multiple options`(_ fixture: EncodeFixture<ListSelectOptions?>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == ListSelectOption {
    fileprivate static func listSelectOption(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectOption($1) }
        )
    }
}

extension EncodeFixture where T == ListSelectOptions? {
    fileprivate static func listSelectOptions(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectOptions($1) }
        )
    }
}
