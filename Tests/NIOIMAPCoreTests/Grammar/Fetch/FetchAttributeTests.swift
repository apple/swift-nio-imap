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
        let inputs: [(FetchAttribute, EncodingCapabilities, String, UInt)] = [
            (.envelope, [], "ENVELOPE", #line),
            (.flags, [], "FLAGS", #line),
            (.uid, [], "UID", #line),
            (.internalDate, [], "INTERNALDATE", #line),
            (.rfc822(.header), [], "RFC822.HEADER", #line),
            (.bodyStructure(extensions: false), [], "BODY", #line),
            (.bodyStructure(extensions: true), [], "BODYSTRUCTURE", #line),
            (.bodySection(peek: false, .init(kind: .header), nil), [], "BODY[HEADER]", #line),
            (.bodySection(peek: true, .init(kind: .header), nil), [], "BODY.PEEK[HEADER]", #line),
            (.binarySize(section: [1]), [.binary], "BINARY.SIZE[1]", #line),
            (.binary(peek: true, section: [1, 2, 3], partial: nil), [.binary], "BINARY.PEEK[1.2.3]", #line),
            (.binary(peek: false, section: [3, 4, 5], partial: nil), [.binary], "BINARY[3.4.5]", #line),
            (.modifierSequenceValue(.zero), [], "0", #line),
            (.modifierSequenceValue(3), [], "3", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchAttribute($0) })
    }

    func testEncodeList() {
        let inputs: [([FetchAttribute], EncodingCapabilities, String, UInt)] = [
            ([.envelope], [], "(ENVELOPE)", #line),
            ([.flags, .internalDate, .rfc822(.size)], [], "FAST", #line),
            ([.internalDate, .rfc822(.size), .flags], [], "FAST", #line),
            ([.flags, .internalDate, .rfc822(.size), .envelope], [], "ALL", #line),
            ([.rfc822(.size), .flags, .envelope, .internalDate], [], "ALL", #line),
            ([.flags, .internalDate, .rfc822(.size), .envelope, .bodyStructure(extensions: false)], [], "FULL", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822(.size), .internalDate, .envelope], [], "FULL", #line),
            ([.flags, .bodyStructure(extensions: true), .rfc822(.size), .internalDate, .envelope], [], "(FLAGS BODYSTRUCTURE RFC822.SIZE INTERNALDATE ENVELOPE)", #line),
            ([.flags, .bodyStructure(extensions: false), .rfc822(.size), .internalDate, .envelope, .uid], [], "(FLAGS BODY RFC822.SIZE INTERNALDATE ENVELOPE UID)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchAttributeList($0) })
    }
}
