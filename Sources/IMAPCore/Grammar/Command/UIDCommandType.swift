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

extension IMAPCore {

    public enum UIDCommandType: Equatable {
        case copy([IMAPCore.SequenceRange], Mailbox)
        case move([IMAPCore.SequenceRange], Mailbox)
        case fetch([IMAPCore.SequenceRange], FetchType, [FetchModifier])
        case search(returnOptions: [SearchReturnOption], program: SearchProgram)
        case store([IMAPCore.SequenceRange], [StoreModifier], StoreAttributeFlags)
        case uidExpunge([IMAPCore.SequenceRange])

        init?(commandType: CommandType) {
            switch commandType {
            case .copy(let arg1, let arg2):
                self = .copy(arg1, arg2)
            case .fetch(let arg1, let arg2, let arg3):
                self = .fetch(arg1, arg2, arg3)
            case .store(let arg1, let arg2, let arg3):
                self = .store(arg1, arg2, arg3)
            case .search(returnOptions: let options, program: let program):
                self = .search(returnOptions: options, program: program)
            case .move(let arg1, let arg2):
                self = .move(arg1, arg2)
            default:
                return nil
            }
        }
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeUIDCommandType(_ command: IMAPCore.UIDCommandType) -> Int {
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

    private mutating func writeUIDCommandType_search(returnOptions: [IMAPCore.SearchReturnOption], program: IMAPCore.SearchProgram) -> Int {
        self.writeString("SEARCH") +
        self.writeIfExists(returnOptions) { (options) -> Int in
            self.writeSearchReturnOptions(options)
        } +
        self.writeSpace() +
        self.writeSearchProgram(program)
    }

}
