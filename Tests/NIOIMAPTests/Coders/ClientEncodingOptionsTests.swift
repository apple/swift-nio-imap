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
import Testing

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

@Suite struct ClientEncodingOptionsTests {
    @Test("getting effective options")
    func gettingEffectiveOptions() {
        #expect(
            ClientEncodingOptions(
                userOptions: .automatic,
                automatic: .a
            ).encodingOptions
                == .a
        )
        #expect(
            ClientEncodingOptions(
                userOptions: .automatic,
                automatic: .b
            ).encodingOptions
                == .b
        )
        #expect(
            ClientEncodingOptions(
                userOptions: .fixed(.a),
                automatic: .b
            ).encodingOptions
                == .a
        )
        #expect(
            ClientEncodingOptions(
                userOptions: .fixed(.b),
                automatic: .a
            ).encodingOptions
                == .b
        )
    }

    @Test("update with response")
    func updateWithResponse() {
        var sut = ClientEncodingOptions(userOptions: .automatic)

        #expect(sut.encodingOptions == CommandEncodingOptions())

        sut.updateAutomaticOptions(response: .untagged(.capabilityData([.imap4, .literalMinus])))
        #expect(
            sut.encodingOptions
                == CommandEncodingOptions(
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
        #expect(
            sut.encodingOptions
                == CommandEncodingOptions(
                    useNonSynchronizingLiteralPlus: true,
                    useBinaryLiteral: true
                )
        )
    }

    @Test("updating auto when using fixed")
    func updatingAutoWhenUsingFixed() {
        var sut = ClientEncodingOptions(userOptions: .fixed(.a))

        #expect(sut.encodingOptions == .a)

        sut.updateAutomaticOptions(response: .untagged(.capabilityData([.imap4, .literalMinus])))
        #expect(sut.encodingOptions == .a)

        sut.userOptions = .automatic
        #expect(
            sut.encodingOptions
                == CommandEncodingOptions(
                    useNonSynchronizingLiteralMinus: true
                )
        )
    }
}
