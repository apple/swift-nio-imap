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

@Suite("MessageIdentifierSet")
struct MessageIdentifierSetTests {
    @Test func `convert to sequence number`() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<SequenceNumber>(input)
        #expect(output == [1...5, 10...15, 20...30])
    }

    @Test func `convert to UID`() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<UID>(input)
        #expect(output == [1...5, 10...15, 20...30])
    }

    @Test func suffix() {
        #expect(UIDSet().suffix(0) == UIDSet())
        #expect(UIDSet([1]).suffix(0) == UIDSet())
        #expect(UIDSet([100, 200]).suffix(0) == UIDSet())

        #expect(UIDSet([100, 200]).suffix(1) == UIDSet([200]))
        #expect(UIDSet([100, 200]).suffix(2) == UIDSet([100, 200]))
        #expect(UIDSet([100, 200]).suffix(3) == UIDSet([100, 200]))

        #expect(UIDSet([200...299]).suffix(0) == UIDSet())
        #expect(UIDSet([200...299]).suffix(1) == UIDSet([299]))
        #expect(UIDSet([200...299]).suffix(2) == UIDSet([298...299]))
        #expect(UIDSet([200...299]).suffix(3) == UIDSet([297...299]))

        #expect(UIDSet([100, 200...299]).suffix(0) == UIDSet())
        #expect(UIDSet([100, 200...299]).suffix(1) == UIDSet([299]))
        #expect(UIDSet([100, 200...299]).suffix(2) == UIDSet([298...299]))
        #expect(UIDSet([100, 200...299]).suffix(3) == UIDSet([297...299]))

        #expect(UIDSet([100...102, 200...202]).suffix(0) == UIDSet())
        #expect(UIDSet([100...102, 200...202]).suffix(1) == UIDSet([202]))
        #expect(UIDSet([100...102, 200...202]).suffix(2) == UIDSet([201...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(3) == UIDSet([200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(4) == UIDSet([102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(5) == UIDSet([101...102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(6) == UIDSet([100...102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(7) == UIDSet([100...102, 200...202]))

        #expect(UIDSet.all.suffix(0) == UIDSet())
        #expect(UIDSet.all.suffix(1) == UIDSet([4_294_967_295]))
        #expect(UIDSet.all.suffix(2) == UIDSet([4_294_967_294...4_294_967_295]))
    }
}
