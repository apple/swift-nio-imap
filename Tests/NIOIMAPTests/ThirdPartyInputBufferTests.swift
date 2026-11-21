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

import NIOIMAPCore
import Testing

/// Parsing from outside the library, with public API only and without the `Lifetimes` feature: reads
/// appended to an `IMAPInputBuffer` are kept by reference, so a large literal reaches the caller uncopied.
@Suite("Third-party input buffer")
struct ThirdPartyInputBufferTests {
    private static let payloadSize = 64 * 1_024

    @Test("reads appended outside the library parse, and deliver a large literal uncopied")
    func largeLiteralIsNotCopied() throws {
        let body = [UInt8](repeating: UInt8(ascii: "x"), count: Self.payloadSize)
        var input = IMAPInputBuffer()
        input.append(Array("* 1 FETCH (RFC822.TEXT {\(Self.payloadSize)}\r\n".utf8))
        input.append(body)
        input.append(Array(")\r\n".utf8))
        let bodyStart = body.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        let bodyAddresses = bodyStart..<(bodyStart + UInt(body.count))

        var parser = ResponseParser()
        var payloads: [IMAPBuffer] = []
        while let response = try parser.parseResponseStream(buffer: &input) {
            guard case .response(.fetch(.streamingBytes(let bytes))) = response else { continue }
            payloads.append(bytes)
        }

        #expect(input.count == 0)
        #expect(payloads.reduce(0) { $0 + $1.count } == Self.payloadSize)
        #expect(
            payloads.allSatisfy { payload in
                bodyAddresses.contains(payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) })
            },
            "the literal should refer to the read it arrived in"
        )
    }
}
