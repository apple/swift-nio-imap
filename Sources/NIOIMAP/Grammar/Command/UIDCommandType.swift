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

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeUIDCommandType(_ command: NIOIMAP.UIDCommandType) -> Int {
        switch command {
        case let .copy(sequence, mailbox):
            return
                self.writeString("COPY ") +
                self.writeSequenceSet(sequence) +
                self.writeSpace() +
                self.writeMailbox(mailbox)

        case let .fetch(set, atts, modifiers):
            return
                self.writeString("FETCH ") +
                self.writeSequenceSet(set) +
                self.writeSpace() +
                self.writeFetchType(atts) +
                self.writeIfExists(modifiers) { (modifiers) -> Int in
                    self.writeFetchModifiers(modifiers)
                }

        case let .store(set, modifiers, flags):
            return
                self.writeString("STORE ") +
                self.writeSequenceSet(set) +
                self.writeIfExists(modifiers) { (modifiers) -> Int in
                    self.writeStoreModifiers(modifiers)
                } +
                self.writeSpace() +
                self.writeStoreAttributeFlags(flags)

        case let .uidExpunge(set):
            return
                self.writeString("EXPUNGE ") +
                self.writeSequenceSet(set)

        case .search(let returnOptions, let program):
            return self.writeUIDCommandType_search(returnOptions: returnOptions, program: program)

        case .move(let set, let mailbox):
            return
                self.writeString("MOVE ") +
                self.writeSequenceSet(set) +
                self.writeSpace() +
                self.writeMailbox(mailbox)
        }
    }

    private mutating func writeUIDCommandType_search(returnOptions: [NIOIMAP.SearchReturnOption], program: NIOIMAP.SearchProgram) -> Int {
        self.writeString("SEARCH") +
        self.writeIfExists(returnOptions) { (options) -> Int in
            self.writeSearchReturnOptions(options)
        } +
        self.writeSpace() +
        self.writeSearchProgram(program)
    }

}
