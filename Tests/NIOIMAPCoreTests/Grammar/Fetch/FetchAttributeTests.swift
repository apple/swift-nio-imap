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
import XCTest

class FetchAttributeTests: EncodeTestClass {}

// MARK: - IMAP

extension FetchAttributeTests {
    func testEncode() {
        let inputs: [(FetchAttribute, EncodingCapabilities, EncodingOptions, String, UInt)] = [
            (.envelope, [], .default, "ENVELOPE", #line),
            (.flags, [], .default, "FLAGS", #line),
            (.uid, [], .default, "UID", #line),
            (.internalDate, [], .default, "INTERNALDATE", #line),
            (.rfc822Header, [], .default, "RFC822.HEADER", #line),
            (.rfc822Size, [], .default, "RFC822.SIZE", #line),
            (.rfc822Text, [], .default, "RFC822.TEXT", #line),
            (.rfc822, [], .default, "RFC822", #line),
            (.bodyStructure(extensions: false), [], .default, "BODY", #line),
            (.bodyStructure(extensions: true), [], .default, "BODYSTRUCTURE", #line),
            (.bodySection(peek: false, .init(kind: .header), nil), [], .default, "BODY[HEADER]", #line),
            (.bodySection(peek: true, .init(kind: .header), nil), [], .default, "BODY.PEEK[HEADER]", #line),
            (.binarySize(section: [1]), [.binary], .default, "BINARY.SIZE[1]", #line),
            (.binary(peek: true, section: [1, 2, 3], partial: nil), [.binary], .default, "BINARY.PEEK[1.2.3]", #line),
            (.binary(peek: false, section: [3, 4, 5], partial: nil), [.binary], .default, "BINARY[3.4.5]", #line),
            (.modifierSequenceValue(.zero), [], .default, "0", #line),
            (.modifierSequenceValue(3), [], .default, "3", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchAttribute($0) })
    }

    func testEncodeList() {
        let inputs: [([FetchAttribute], EncodingCapabilities, EncodingOptions, String, UInt)] = [
            ([.envelope], [], .default, "(ENVELOPE)", #line),
            ([.flags, .internalDate, .rfc822Size], [], .default, "FAST", #line),
            ([.internalDate, .rfc822Size, .flags], [], .default, "FAST", #line),
            ([.flags, .internalDate, .rfc822Size, .envelope], [], .default, "ALL", #line),
            ([.rfc822Size, .flags, .envelope, .internalDate], [], .default, "ALL", #line),
            ([.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)], [], .default, "FULL", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope], [], .default, "FULL", #line),
            ([.flags, .bodyStructure(extensions: true), .rfc822Size, .internalDate, .envelope], [], .default, "(FLAGS BODYSTRUCTURE RFC822.SIZE INTERNALDATE ENVELOPE)", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822Size, .internalDate, .envelope, .uid], [], .default, "(FLAGS BODY RFC822.SIZE INTERNALDATE ENVELOPE UID)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchAttributeList($0) })
    }
}
