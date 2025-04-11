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
@testable import NIOIMAP
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

extension CommandEncodingOptions {
    static var a: CommandEncodingOptions {
        CommandEncodingOptions(
            useQuotedString: true,
            useSynchronizingLiteral: false,
            useNonSynchronizingLiteralPlus: true,
            useNonSynchronizingLiteralMinus: false,
            useBinaryLiteral: true
        )
    }

    static var b: CommandEncodingOptions {
        CommandEncodingOptions(
            useQuotedString: false,
            useSynchronizingLiteral: true,
            useNonSynchronizingLiteralPlus: false,
            useNonSynchronizingLiteralMinus: false,
            useBinaryLiteral: false
        )
    }
}

class ClientEncodingOptionsTests: XCTestCase {
    func testGettingEffectiveOptions() {
        XCTAssertEqual(
            ClientEncodingOptions(
                userOptions: .automatic,
                automatic: .a
            ).encodingOptions,
            .a
        )
        XCTAssertEqual(
            ClientEncodingOptions(
                userOptions: .automatic,
                automatic: .b
            ).encodingOptions,
            .b
        )
        XCTAssertEqual(
            ClientEncodingOptions(
                userOptions: .fixed(.a),
                automatic: .b
            ).encodingOptions,
            .a
        )
        XCTAssertEqual(
            ClientEncodingOptions(
                userOptions: .fixed(.b),
                automatic: .a
            ).encodingOptions,
            .b
        )
    }

    func testUpdateWithResponse() {
        var sut = ClientEncodingOptions(userOptions: .automatic)

        XCTAssertEqual(sut.encodingOptions, CommandEncodingOptions())

        sut.updateAutomaticOptions(response: .untagged(.capabilityData([.imap4, .literalMinus])))
        XCTAssertEqual(
            sut.encodingOptions,
            CommandEncodingOptions(
                useNonSynchronizingLiteralMinus: true
            )
        )

        sut.updateAutomaticOptions(
            response: .tagged(
                TaggedResponse(
                    tag: "A",
                    state: .ok(
                        ResponseText(
                            code: .capability([.imap4rev1, .literalPlus, .binary]),
                            text: "Done"
                        )
                    )
                )
            )
        )
        XCTAssertEqual(
            sut.encodingOptions,
            CommandEncodingOptions(
                useNonSynchronizingLiteralPlus: true,
                useBinaryLiteral: true
            )
        )
    }

    func testUpdatingAutoWhenUsingFixed() {
        var sut = ClientEncodingOptions(userOptions: .fixed(.a))

        XCTAssertEqual(sut.encodingOptions, .a)

        sut.updateAutomaticOptions(response: .untagged(.capabilityData([.imap4, .literalMinus])))
        XCTAssertEqual(sut.encodingOptions, .a)

        sut.userOptions = .automatic
        XCTAssertEqual(
            sut.encodingOptions,
            CommandEncodingOptions(
                useNonSynchronizingLiteralMinus: true
            )
        )
    }
}
